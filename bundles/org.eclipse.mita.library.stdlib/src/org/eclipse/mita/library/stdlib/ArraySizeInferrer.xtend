/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.library.stdlib

import com.google.common.base.Optional
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.expressions.ArrayAccessExpression
import org.eclipse.mita.base.expressions.ValueRange
import org.eclipse.mita.base.types.TypeExpressionSpecifier
import org.eclipse.mita.base.types.TypeReferenceSpecifier
import org.eclipse.mita.base.types.Variance
import org.eclipse.mita.base.typesystem.infra.ElementSizeInferrer
import org.eclipse.mita.base.typesystem.infra.NullSizeInferrer
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.LiteralNumberType
import org.eclipse.mita.base.typesystem.types.LiteralTypeExpression
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.AbstractLoopStatement
import org.eclipse.mita.program.ArrayLiteral
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.EcoreUtil2

import static extension org.eclipse.mita.base.types.TypeUtils.ignoreCoercions
import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import static extension org.eclipse.mita.base.util.BaseUtils.init
import org.eclipse.mita.program.Program
import org.eclipse.emf.ecore.util.EcoreUtil.UsageCrossReferencer
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.IntLiteral
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.expressions.NumericalAddSubtractExpression
import org.eclipse.mita.base.expressions.AdditiveOperator

class ArraySizeInferrer implements ElementSizeInferrer {
	
	@Accessors 
	ElementSizeInferrer delegate = new NullSizeInferrer();
	
	static def Optional<Long> getSize(AbstractType type) {
		return Optional.fromNullable(type?.castOrNull(TypeConstructorType)
				?.typeArguments?.last?.castOrNull(LiteralTypeExpression)
				?.eval()?.castOrNull(Long))
	}
	
	// you should always pass a array<T, ...> here
	static def AbstractType getDataType(AbstractType type) {
		return type?.castOrNull(TypeConstructorType)?.typeArguments?.tail?.head;
	}
		
	protected def AbstractType replaceLastTypeArgument(Substitution sub, TypeConstructorType t, AbstractType typeArg) {
		val tv_t = replaceLastTypeArgument(t, typeArg);
		sub.add(tv_t.key, typeArg);
		return tv_t.value;
	}
	
	protected def replaceLastTypeArgument(TypeConstructorType t, AbstractType typeArg) {
		// hardcoding variance isnt *nice*, but convenient. If need be make this a function argument/default argument.
		return t.typeArguments.last.castOrNull(TypeVariable) -> new TypeConstructorType(t.origin, t.name, t.typeArgumentsAndVariances.init + #[typeArg -> Variance.COVARIANT])
	}	
		
	override unbindSize(ConstraintSystem system, AbstractType t) {
		if(t instanceof TypeConstructorType) {
			return replaceLastTypeArgument(t, system.newTypeVariable(t.origin)).value;
		}
		
		return ElementSizeInferrer.super.unbindSize(system, t);
	}
	
	override Optional<Pair<EObject, AbstractType>> infer(ConstraintSystem system, Substitution sub, Resource r, EObject obj, AbstractType type) {
		return doInfer(system, sub, r, obj, type);
	}
	
	protected dispatch def Optional<Pair<EObject, AbstractType>> doInfer(ConstraintSystem system, Substitution sub, Resource r, ArrayLiteral expression, TypeConstructorType type) {
		val dataTypeMax = delegate.max(system, r, expression, expression.values.map[BaseUtils.getType(system, sub, it)]);
		if(!dataTypeMax.present) {
			return Optional.of(expression as EObject -> type as AbstractType);
		}
		sub.add(system.getTypeVariable(expression), new TypeConstructorType(expression, type.typeArguments.head,
			#[dataTypeMax.get -> Variance.INVARIANT, 
			new LiteralNumberType(expression, expression.values.length, type.typeArguments.last) -> Variance.COVARIANT]
		));
		return Optional.absent();
	}
		
	protected dispatch def Optional<Pair<EObject, AbstractType>> doInfer(ConstraintSystem system, Substitution sub, Resource r, NewInstanceExpression obj, TypeConstructorType type) {	
		val lastTypespecifierArg = obj.type.typeArguments.last;
		if(lastTypespecifierArg instanceof TypeReferenceSpecifier) {
			replaceLastTypeArgument(sub, type, BaseUtils.getType(system, sub, lastTypespecifierArg));
			return Optional.absent();
		}
		else if(lastTypespecifierArg instanceof TypeExpressionSpecifier) {
			replaceLastTypeArgument(sub, type, BaseUtils.getType(system, sub, lastTypespecifierArg));
			return Optional.absent();
		}
		
		return Optional.of(obj as EObject -> type as AbstractType);
	}
	
	protected dispatch def Optional<Pair<EObject, AbstractType>> doInfer(ConstraintSystem system, Substitution sub, Resource r, ArrayAccessExpression expr, TypeConstructorType type) {
		val arraySelector = expr.arraySelector.ignoreCoercions?.castOrNull(ValueRange);
		if(arraySelector !== null) {
			val ownerType = BaseUtils.getType(system, sub, expr.owner);
			val ownerSize = getSize(ownerType);
			val lowerBound = StaticValueInferrer.infer(arraySelector.lowerBound, [])?.castOrNull(Long) ?: 0L;
			val upperBound = StaticValueInferrer.infer(arraySelector.upperBound, [])?.castOrNull(Long) ?: ownerSize.orNull;
			if(upperBound === null) {
				return Optional.of(expr as EObject -> type as AbstractType);
			}
			replaceLastTypeArgument(sub, type, new LiteralNumberType(expr, upperBound - lowerBound, type.typeArguments.last));
			return Optional.absent;
		}
		Optional.of(expr as EObject -> type as AbstractType);
	}
	
	protected dispatch def Optional<Pair<EObject, AbstractType>> doInfer(ConstraintSystem system, Substitution sub, Resource r, VariableDeclaration variable, TypeConstructorType type) {
		if(!variable.writeable) {
			return delegate.infer(system, sub, r, variable, type);
		}
		/*
		 * Find initial size
		 */
		val variableRoot = EcoreUtil2.getContainerOfType(variable, Program);
		val referencesToVariable = UsageCrossReferencer.find(variable, variableRoot).map[e | e.EObject ];
		val fixedSize = getSize(BaseUtils.getType(system, sub, variable.typeSpecifier))
		if(fixedSize.present) {
			replaceLastTypeArgument(sub, type, new LiteralNumberType(variable, fixedSize.get, type.typeArguments.last))
			return Optional.absent();
		}	
		
		val initialization = variable.initialization ?: (
			referencesToVariable
				.map[it.eContainer]
				.filter(AssignmentExpression)
				.filter[ae |
					val left = ae.varRef; 
					left instanceof ElementReferenceExpression && (left as ElementReferenceExpression).reference === variable 
				]
				.map[it.expression]
				.head
		)
		
		var arrayHasFixedSize = false;
		val initialType = if(initialization !== null) {
			BaseUtils.getType(system, sub, initialization);
		}
		val initialLength = if(initialization !== null) {
			getSize(initialType)
		} 
		else {
			Optional.absent();
		}
		if(!initialLength.present) {
			return Optional.of(variable as EObject -> type as AbstractType);
		}
		var typeArg = getDataType(initialType);
		var length = initialLength.get;

		/*
		 * Strategy is to find all places where this variable is modified and try to infer the length there.
		 */		
		val modifyingExpressions = referencesToVariable.map[ref | 
			val refContainer = ref.eContainer;
			
			if(refContainer instanceof AssignmentExpression) {
				if(refContainer.varRef == ref) {
					// we're actually assigning to this reference, thus modifying it
					refContainer					
				} else {
					// the variable reference is just on the right side. No modification happening
					null
				}
			} else {
				null
			}
		]
		.filterNull;
		
		/*
		 * Check if we can infer the length across all modifications
		 */
		for(expr : modifyingExpressions) {
			/*
			 * First, let's see if we can infer the array length after the modification.
			 */
			var allowedInLoop = arrayHasFixedSize;
			if(expr instanceof AssignmentExpression) {
				val exprType = BaseUtils.getType(system, sub, expr.expression);
				val biggerTypeArg = getDataType(exprType);
				val mbLargerType = delegate.max(system, r, variable, #[typeArg, biggerTypeArg]);
				if(mbLargerType.present) {
					typeArg = mbLargerType.get
				}
				else {
					// try again later, couldn't get max
					return Optional.of(variable as EObject -> type as AbstractType);
				}
				
				if(expr.operator == AssignmentOperator.ADD_ASSIGN) {
					val additionLength = getSize(exprType);
					// try again later
					if(!additionLength.present) return Optional.of(variable as EObject -> type as AbstractType);
					
					length = length + additionLength.get;
				} else if(expr.operator == AssignmentOperator.ASSIGN) {
					val additionLength = getSize(BaseUtils.getType(system, sub, expr.expression));
					// try again later
					if(!additionLength.present) return Optional.of(variable as EObject -> type as AbstractType);
					
					allowedInLoop = true;
					length = Math.max(length, additionLength.get);
				} else {
					// can't infer the length due to unknown operator
					replaceLastTypeArgument(sub, type, new BottomType(expr, '''Cannot infer size when using the «expr.operator.getName()» operator'''));
					return Optional.absent();
				}
			}
			
			/*
			 * Second, see if the modification happens in a loop. In that case we don't bother with trying to infer the length.
			 * Because of block scoping we just have to find a loop container of the modifyingExpression and then make sure that
			 * the loop container and the variable definition are/share a common ancestor.
			 */
			if(!allowedInLoop) {
				val loopContainer = expr.getSharedLoopContainer(variable);
				if(loopContainer !== null) {
					replaceLastTypeArgument(sub, type, new BottomType(expr, '''Cannot infer «type.name» length in loops'''));
					return Optional.absent();
				}	
			}
		}
		
		replaceLastTypeArgument(sub, type, new LiteralNumberType(variable, length, type.typeArguments.last));
		return Optional.absent();
	}
	
	protected dispatch def Optional<Pair<EObject, AbstractType>> doInfer(ConstraintSystem system, Substitution sub, Resource r, TypeReferenceSpecifier obj, TypeConstructorType type) {
		val sizeArg = obj.typeArguments.last;
		val sizeType = if(sizeArg instanceof TypeExpressionSpecifier) {
			val e = sizeArg.value;
			system.getTypeVariable(sizeArg.value);
		}
		else {
			system.getTypeVariable(sizeArg);
		}
		replaceLastTypeArgument(sub, type, sizeType);
		return Optional.absent();
	}
	
	// call delegate for other things
	protected dispatch def Optional<Pair<EObject, AbstractType>> doInfer(ConstraintSystem system, Substitution sub, Resource r, EObject obj, TypeConstructorType type) {
		return delegate.infer(system, sub, r, obj, type);
	}
	
	// error/wait if type is not typeConstructorType
	protected dispatch def Optional<Pair<EObject, AbstractType>> doInfer(ConstraintSystem system, Substitution sub, Resource r, EObject obj, AbstractType type) {
		return Optional.of(obj as EObject -> type as AbstractType);
	}
	
	/**
	 * Finds a loop ancestor of expr which shares a common ancestor with other.
	 */
	protected static def getSharedLoopContainer(EObject expr, EObject other) {
		val loopContainer = EcoreUtil2.getContainerOfType(expr, AbstractLoopStatement);
		if(loopContainer !== null) {
			/* We found a loop containing the modifying expression. Let's make sure they share a parent with the variable declaration. */
			val variableContainer = other.eContainer;
			val sharedAncestor = EcoreUtil2.getAllContainers(loopContainer).findFirst[c | c == variableContainer];
			
			if(variableContainer == loopContainer || sharedAncestor !== null) {
				/* We have a found a string manipulation in a loop. We won't bother trying to infer the new string length. */
				return loopContainer;
			}				
		}
		return null;
	}
	
	override max(ConstraintSystem system, Resource r, EObject objOrProxy, Iterable<AbstractType> _types) {
		val types = _types.filter(TypeConstructorType);
		val firstArg = delegate.max(system, r, objOrProxy, types.map[getDataType(it)]);
		if(firstArg.present) {
			val sndArgCandidates = types.map[it.typeArguments.last];
			if(sndArgCandidates.forall[it instanceof LiteralTypeExpression<?>]) {
				val sndArgValues = sndArgCandidates.map[(it as LiteralTypeExpression<?>).eval()];
				if(sndArgValues.forall[it instanceof Long && (it as Long) >= 0]) {
					val sndArgValue = sndArgValues.filter(Long).max;
					return Optional.of(new TypeConstructorType(null, types.head.typeArguments.head, #[
						firstArg.get -> Variance.INVARIANT,
						new LiteralNumberType(null, sndArgValue, sndArgCandidates.head.castOrNull(LiteralTypeExpression).typeOf) -> Variance.COVARIANT
					]))
				}
			}			
		}

		return Optional.absent;
	}
	
}