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
import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.expressions.StringLiteral
import org.eclipse.mita.base.types.InterpolatedStringLiteral
import org.eclipse.mita.base.types.Variance
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.infra.InferenceContext
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.LiteralNumberType
import org.eclipse.mita.base.typesystem.types.LiteralTypeExpression
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.util.BaseUtils

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.SumConstraint
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.typesystem.constraints.InterpolatedStringExpressionConstraint

class StringSizeInferrer extends ArraySizeInferrer {
	@Inject
	StdlibTypeRegistry typeRegistry;
	
	override getDataTypeIndexes() {
		return #[];
	}
	
	override getSizeTypeIndexes() {
		return #[1];
	}
				
	dispatch def void doCreateConstraints(InferenceContext c, StringLiteral lit, TypeConstructorType type) {
		c.system.associate(new TypeConstructorType(lit, type.name, #[
			type.typeArguments.head -> Variance.INVARIANT, 
			new LiteralNumberType(lit, lit.value.length, type.typeArguments.last) -> Variance.COVARIANT
		]), lit);
	}

	dispatch def void doCreateConstraints(InferenceContext c, InterpolatedStringLiteral expr, TypeConstructorType type) {
		val u32 = typeRegistry.getTypeModelObject(expr, StdlibTypeRegistry.u32TypeQID);
		val u32Type = c.system.getTypeVariable(u32);
		val lengthText = new LiteralNumberType(expr, expr.sumTextParts, u32Type);
		
		// sum expression value part
		val sublengths = expr.content.map[subexpr |
			val result = c.system.newTypeVariable(subexpr);
			c.system.addConstraint(new InterpolatedStringExpressionConstraint(new ValidationIssue("", subexpr), subexpr, result, c.system.getTypeVariable(subexpr)));
			result;
		]

		c.system.associate(type, expr);
		c.system.addConstraint(new SumConstraint(typeVariableToTypeConstructorType(c, c.system.getTypeVariable(expr), type).typeArguments.last as TypeVariable, #[lengthText] + sublengths, new ValidationIssue("", expr)))
	}
		
	protected def long sumTextParts(InterpolatedStringLiteral expr) {
		val texts = StringGenerator.getOriginalTexts(expr)
		if (texts.nullOrEmpty) {
			0
		} else {
			texts.map[x | x.length as long ].reduce[x1, x2| x1 + x2 ];
		}
	}
	
//	override max(ConstraintSystem system, Resource r, EObject objOrProxy, Iterable<AbstractType> _types) {
//		val types = _types.filter(TypeConstructorType);
//		val sndArgCandidates = types.map[it.typeArguments.last];
//		if(sndArgCandidates.forall[it instanceof LiteralTypeExpression<?>]) {
//			val sndArgValues = sndArgCandidates.map[(it as LiteralTypeExpression<?>).eval()];
//			if(sndArgValues.forall[it instanceof Long && (it as Long) >= 0]) {
//				val sndArgValue = sndArgValues.filter(Long).max;
//				return Optional.of(new TypeConstructorType(null, types.head.typeArguments.head, #[
//					new LiteralNumberType(null, sndArgValue, sndArgCandidates.head.castOrNull(LiteralTypeExpression).typeOf) -> Variance.COVARIANT
//				]))
//			}
//		}			
//		
//
//		return Optional.absent;
//	}		
	
}