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
import org.eclipse.emf.ecore.util.EcoreUtil.UsageCrossReferencer
import org.eclipse.mita.base.expressions.ArrayAccessExpression
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.ValueRange
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.TypeExpressionSpecifier
import org.eclipse.mita.base.types.TypeReferenceSpecifier
import org.eclipse.mita.base.types.Variance
import org.eclipse.mita.base.typesystem.infra.InferenceContext
import org.eclipse.mita.base.typesystem.infra.NullSizeInferrer
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.LiteralNumberType
import org.eclipse.mita.base.typesystem.types.LiteralTypeExpression
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.AbstractLoopStatement
import org.eclipse.mita.program.ArrayLiteral
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.EcoreUtil2

import static extension org.eclipse.mita.base.types.TypeUtils.ignoreCoercions
import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull

import static extension org.eclipse.mita.base.util.BaseUtils.init
import org.eclipse.mita.base.typesystem.constraints.MaxConstraint
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.infra.TypeSizeInferrer
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.base.typesystem.constraints.SumConstraint
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry

class ArraySizeInferrer extends GenericContainerSizeInferrer {
		
	override getDataTypeIndexes() {
		return #[1];
	}
	
	override getSizeTypeIndexes() {
		return #[2];
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, ArrayLiteral lit, TypeConstructorType t) {	
		val innerDataType = c.system.newTypeVariable(lit);
		val oldDataType = t.typeArguments.get(1)
		c.system.addConstraint(new MaxConstraint(innerDataType, lit.values.map[
				c.system.getTypeVariable(it)
			] 
			// add the original type here to make for example [1,2,3]: array<uint32, _> (because of other use) type to *uint32* instead of xint8 
			+ #[oldDataType], new ValidationIssue('''''', lit)));
		
		c.system.associate(new TypeConstructorType(lit, t.name, #[
			t.typeArguments.head -> Variance.INVARIANT, 
			innerDataType -> Variance.INVARIANT, 
			new LiteralNumberType(lit, lit.values.length, t.typeArguments.last) -> Variance.COVARIANT
		]), lit);
	}

//	protected dispatch def void doInfer(InferenceContext c, NewInstanceExpression obj, TypeConstructorType type) {	
//		val lastTypespecifierArg = obj.type.typeArguments.last;
//		if(lastTypespecifierArg instanceof TypeReferenceSpecifier) {
//			replaceLastTypeArgument(c.sub, type, BaseUtils.getType(c.system, c.sub, lastTypespecifierArg));
//		}
//		else if(lastTypespecifierArg instanceof TypeExpressionSpecifier) {
//			replaceLastTypeArgument(c.sub, type, BaseUtils.getType(c.system, c.sub, lastTypespecifierArg));
//		}
//		
//		return Optional.of(c);
//	}
//	
	dispatch def void doCreateConstraints(InferenceContext c, ArrayAccessExpression expr, TypeConstructorType type) {
		val arraySelector = expr.arraySelector.ignoreCoercions?.castOrNull(ValueRange);
		if(arraySelector !== null) {
			val u32 = typeRegistry.getTypeModelObject(expr, StdlibTypeRegistry.u32TypeQID);
			val u32Type = c.system.getTypeVariable(u32);
			val ownerSize = typeVariableToTypeConstructorType(c, c.system.getTypeVariable(expr.owner), type).typeArguments.last;
			val lowerBound = new LiteralNumberType(arraySelector.lowerBound, -1 * (StaticValueInferrer.infer(arraySelector.lowerBound, [])?.castOrNull(Long) ?: 0L), u32Type);
			val upperBoundInferred = StaticValueInferrer.infer(arraySelector.upperBound, [])?.castOrNull(Long);
			val upperBound = if(upperBoundInferred !== null) {
				new LiteralNumberType(arraySelector.upperBound, upperBoundInferred, u32Type);
			}
			else {
				ownerSize	
			}
			val exprSizeType = typeVariableToTypeConstructorType(c, c.system.getTypeVariable(expr), type).typeArguments.last as TypeVariable;
			c.system.addConstraint(new SumConstraint(exprSizeType, #[upperBound, lowerBound], new ValidationIssue('''''', expr)));
		}
		c.system.associate(type, expr);
	}
//	
//	
//	protected dispatch def void doInfer(InferenceContext c, TypeReferenceSpecifier obj, TypeConstructorType type) {
//		val sizeArg = obj.typeArguments.last;
//		val sizeType = if(sizeArg instanceof TypeExpressionSpecifier) {
//			val e = sizeArg.value;
//			c.system.getTypeVariable(sizeArg.value);
//		}
//		else {
//			c.system.getTypeVariable(sizeArg);
//		}
//		replaceLastTypeArgument(c.sub, type, sizeType);
//	}
//	//	
//	/**
//	 * Finds a loop ancestor of expr which shares a common ancestor with other.
//	 */
//	protected static def getSharedLoopContainer(EObject expr, EObject other) {
//		val loopContainer = EcoreUtil2.getContainerOfType(expr, AbstractLoopStatement);
//		if(loopContainer !== null) {
//			/* We found a loop containing the modifying expression. Let's make sure they share a parent with the variable declaration. */
//			val variableContainer = other.eContainer;
//			val sharedAncestor = EcoreUtil2.getAllContainers(loopContainer).findFirst[c | c == variableContainer];
//			
//			if(variableContainer == loopContainer || sharedAncestor !== null) {
//				/* We have a found a string manipulation in a loop. We won't bother trying to infer the new string length. */
//				return loopContainer;
//			}				
//		}
//		return null;
//	}
//	
//	override max(ConstraintSystem system, Resource r, EObject objOrProxy, Iterable<AbstractType> _types) {
//		val types = _types.filter(TypeConstructorType);
//		val firstArg = delegate.max(system, r, objOrProxy, types.map[getDataType(it)]);
//		if(firstArg.present) {
//			val sndArgCandidates = types.map[it.typeArguments.last];
//			if(sndArgCandidates.forall[it instanceof LiteralTypeExpression<?>]) {
//				val sndArgValues = sndArgCandidates.map[(it as LiteralTypeExpression<?>).eval()];
//				if(sndArgValues.forall[it instanceof Long && (it as Long) >= 0]) {
//					val sndArgValue = sndArgValues.filter(Long).max;
//					return Optional.of(new TypeConstructorType(null, types.head.typeArguments.head, #[
//						firstArg.get -> Variance.INVARIANT,
//						new LiteralNumberType(null, sndArgValue, sndArgCandidates.head.castOrNull(LiteralTypeExpression).typeOf) -> Variance.COVARIANT
//					]))
//				}
//			}			
//		}
//
//		return Optional.absent;
//	}
	
}