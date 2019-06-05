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
import org.eclipse.mita.base.types.TypeExpressionSpecifier
import org.eclipse.mita.base.types.TypeReferenceSpecifier
import org.eclipse.mita.base.types.Variance
import org.eclipse.mita.base.typesystem.infra.ElementSizeInferrer
import org.eclipse.mita.base.typesystem.infra.NullSizeInferrer
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.LiteralNumberType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.AbstractLoopStatement
import org.eclipse.mita.program.ArrayLiteral
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.EcoreUtil2

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import static extension org.eclipse.mita.base.util.BaseUtils.init

class ArraySizeInferrer implements ElementSizeInferrer {
	
	@Accessors 
	ElementSizeInferrer delegate = new NullSizeInferrer();
		
	protected def AbstractType replaceLastTypeArgument(Substitution sub, TypeConstructorType t, AbstractType typeArg) {
		val tv_t = replaceLastTypeArgument(t, typeArg);
		sub.add(tv_t.key, typeArg);
		return tv_t.value;
	}
	
	protected def replaceLastTypeArgument(TypeConstructorType t, AbstractType typeArg) {
		// hardcoding variance isnt *nice*, but convenient. If need be make this a function argument/default argument.
		return t.typeArgumentsAndVariances.last.key.castOrNull(TypeVariable) -> new TypeConstructorType(t.origin, t.name, t.typeArgumentsAndVariances.init + #[typeArg -> Variance.COVARIANT])
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
	
	// TODO: call maximum on literal types for first type argument.
	protected dispatch def Optional<Pair<EObject, AbstractType>> doInfer(ConstraintSystem system, Substitution sub, Resource r, ArrayLiteral expression, TypeConstructorType type) {
		replaceLastTypeArgument(sub, type, new LiteralNumberType(expression, expression.values.length));
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
	
	protected dispatch def Optional<Pair<EObject, AbstractType>> doInfer(ConstraintSystem system, Substitution sub, Resource r, EObject obj, AbstractType type) {
		return Optional.of(obj -> type);
	}
	
		
	
//	protected def dispatch ElementSizeInferenceResult isolatedDoInfer(ArrayAccessExpression expr) {
//		val arraySelector = expr.arraySelector.ignoreCoercions?.castOrNull(ValueRange);
//		if(arraySelector === null) {
//			return _isolatedDoInfer(expr as EObject);
//		}
//		val ownerSize = expr.owner?.isolatedDoInfer;
//		val validOwnerSize = ownerSize?.castOrNull(ValidElementSizeInferenceResult);
//		val lowerBound = StaticValueInferrer.infer(arraySelector.lowerBound, [])?.castOrNull(Long) ?: (0L);
//		val upperBound = StaticValueInferrer.infer(arraySelector.upperBound, [])?.castOrNull(Long) ?: (if(validOwnerSize !== null) validOwnerSize.elementCount as Long);
//		if(upperBound === null) {
//			return _isolatedDoInfer(expr as EObject);
//		}
//		val result = newValidResult(expr, upperBound - lowerBound);
//		result.children += ownerSize.children;
//		
//		return result;
//	}
//	
//	
//	protected dispatch override ElementSizeInferenceResult doInfer(VariableDeclaration variable, AbstractType type) {
//		/*
//		 * Find initial size
//		 */
//		val variableRoot = EcoreUtil2.getContainerOfType(variable, Program);
//		val referencesToVariable = UsageCrossReferencer.find(variable, variableRoot).map[e | e.EObject ];
//		val initialization = variable.initialization ?: (
//			referencesToVariable
//				.map[it.eContainer]
//				.filter(AssignmentExpression)
//				.filter[ae |
//					val left = ae.varRef; 
//					left instanceof ElementReferenceExpression && (left as ElementReferenceExpression).reference === variable 
//				]
//				.map[it.expression]
//				.head
//		)
//		var arrayHasFixedSize = false;
//		val initialLength = if(initialization !== null) {
//			if(initialization instanceof NewInstanceExpression) {
//				arrayHasFixedSize = true;
//				initialization.inferFixedSize();
//			} else {
//				initialization.isolatedDoInfer();
//			}
//		} else {
//			newInvalidResult(variable, "Cannot infer size of initialization");
//		}
//		if(initialLength instanceof InvalidElementSizeInferenceResult) {
//			return initialLength;
//		}
//		var length = (initialLength as ValidElementSizeInferenceResult).elementCount;
//
//		/*
//		 * Strategy is to find all places where this variable is modified and try to infer the length there.
//		 */		
//		val modifyingExpressions = referencesToVariable.map[ref | 
//			val refContainer = ref.eContainer;
//			
//			if(refContainer instanceof AssignmentExpression) {
//				if(refContainer.varRef == ref) {
//					// we're actually assigning to this reference, thus modifying it
//					refContainer					
//				} else {
//					// the variable reference is just on the right side. No modification happening
//					null
//				}
//			} else if(refContainer instanceof FeatureCall) {
//				refContainer
//			} else {
//				null
//			}
//		]
//		.filterNull;
//		
//		/*
//		 * Check if we can infer the length across all modifications
//		 */
//		for(expr : modifyingExpressions) {
//			/*
//			 * First, let's see if we can infer the array length after the modification.
//			 */
//			var allowedInLoop = arrayHasFixedSize;
//			if(expr instanceof AssignmentExpression) {
//				if(expr.operator == AssignmentOperator.ADD_ASSIGN) {
//					val additionLength = expr.expression.infer();
//					if(!additionLength.isValid) return additionLength;
//					
//					length += (additionLength as ValidElementSizeInferenceResult).elementCount;
//				} else if(expr.operator == AssignmentOperator.ASSIGN) {
//					val additionLength = expr.expression.infer();
//					if(!additionLength.isValid) return additionLength;
//					
//					allowedInLoop = true;
//					length = Math.max(length, (additionLength as ValidElementSizeInferenceResult).elementCount);
//				} else {
//					// can't infer the length due to unknown operator
//					return newInvalidResult(expr, '''Cannot infer size when using the «expr.operator.getName()» operator''')
//				}
//			}
//			
//			/*
//			 * Second, see if the modification happens in a loop. In that case we don't bother with trying to infer the length.
//			 * Because of block scoping we just have to find a loop container of the modifyingExpression and then make sure that
//			 * the loop container and the variable definition are/share a common ancestor.
//			 */
//			if(!allowedInLoop) {
//				val loopContainer = expr.getSharedLoopContainer(variable);
//				if(loopContainer !== null) {
//					return newInvalidResult(expr, '''Cannot infer «BaseUtils.getType(variable)?.name ?: "array"» length in loops''');
//				}	
//			}
//		}
//		
//		return newValidResult(variable, length);
//	}
//	
//	override protected dispatch doInfer(NewInstanceExpression obj, AbstractType type) {
//		
//	}
//	
//	def protected dispatch doInfer(ArrayLiteral obj, AbstractType type) {
//		val parentType = BaseUtils.getType(obj.eContainer);
//		
//		val typeOfChildren = (parentType as TypeConstructorType).typeArguments.tail.head;
//		
//		val result = new ValidElementSizeInferenceResult(obj, parentType, obj.values.length);
//		 
//		if(typeOfChildren.name == StdlibTypeRegistry.arrayTypeQID.lastSegment) {
//			result.children.add(infer(obj.values.head));	
//		}
//		else {
//			result.children.add(super.infer(obj.values.head));	
//		}
//		return result;			
//	}
//	
//	override protected dispatch doInfer(ElementReferenceExpression obj, AbstractType type) {
//		val arraySelectors = obj.arraySelector.map[it.ignoreCoercions];
//		if(obj.arrayAccess && arraySelectors.head instanceof ValueRange) {
//			val valRange = arraySelectors.head as ValueRange;
//			
//			val parentType = BaseUtils.getType(obj);
//			val typeOfChildren = (parentType as TypeConstructorType).typeArguments.tail.head;
//			
//			val lowerBound = StaticValueInferrer.infer(valRange.lowerBound, [x |]);
//			val upperBound = StaticValueInferrer.infer(valRange.upperBound, [x |]);
//			if(!(lowerBound instanceof Integer && upperBound instanceof Integer)) {
//				return new InvalidElementSizeInferenceResult(obj, parentType, "can not infer size for this range");
//			}
//			val elCount = (upperBound as Integer) - (lowerBound as Integer) + 1;
//			
//			val result = new ValidElementSizeInferenceResult(obj, parentType, elCount);
//			result.children.add(obj.inferFromType(typeOfChildren));
//			return result;
//		} else {
//			return super._doInfer(obj, type);
//		}
//	}
	
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
}