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

class StringSizeInferrer extends ArraySizeInferrer {
	@Inject
	StdlibTypeRegistry typeRegistry;
				
	protected dispatch def Optional<InferenceContext> doInfer(InferenceContext c, StringLiteral expression, TypeConstructorType type) {
		replaceLastTypeArgument(c.sub, type, new LiteralNumberType(expression, expression.value.length, typeRegistry.getIntegerTypes(expression).findFirst[it.name == "uint32"]));
		return Optional.absent;
	}

	protected dispatch def Optional<InferenceContext> doInfer(InferenceContext c, InterpolatedStringLiteral expr, TypeConstructorType type) {
		var length = expr.sumTextParts
		
		// sum expression value part
		for(subexpr : expr.content) {
			val tsub = BaseUtils.getType(subexpr);
			var typeLengthInBytes = switch(tsub?.name) {
				case 'uint32': 10L
				case 'uint16':  5L
				case 'uint8' :  3L
				case 'int32' : 11L
				case 'int16' :  6L
				case 'int8'  :  4L
				case 'xint32': 11L
				case 'xint16':  6L
				case 'xint8' :  4L
				case 'bool'  :  1L
				// https://stackoverflow.com/a/1934253
				case 'double': StringGenerator.DOUBLE_PRECISION + 1L + 1L + 5L + 1L
				case 'float':  StringGenerator.DOUBLE_PRECISION + 1L + 1L + 5L + 1L
				case 'string':    {
					val stringSize = getSize(BaseUtils.getType(c.system, c.sub, subexpr));
					if(stringSize.present) {
						stringSize.get;
					} else {
						return Optional.of(c);
					}
				}
				default: null
			}
			
			if(typeLengthInBytes === null) {
				c.sub.add(c.system.getTypeVariable(subexpr), new BottomType(subexpr, "Cannot interpolate expressions of type " + tsub))
				return Optional.absent;
			} else {
				length += typeLengthInBytes;
			}
		}

		replaceLastTypeArgument(c.sub, type, new LiteralNumberType(expr, length, typeRegistry.getIntegerTypes(expr).findFirst[it.name == "uint32"]));
		return Optional.absent();
	}
		
	protected def long sumTextParts(InterpolatedStringLiteral expr) {
		val texts = StringGenerator.getOriginalTexts(expr)
		if (texts.nullOrEmpty) {
			0
		} else {
			texts.map[x | x.length as long ].reduce[x1, x2| x1 + x2 ];
		}
	}
	
	override max(ConstraintSystem system, Resource r, EObject objOrProxy, Iterable<AbstractType> _types) {
		val types = _types.filter(TypeConstructorType);
		val sndArgCandidates = types.map[it.typeArguments.last];
		if(sndArgCandidates.forall[it instanceof LiteralTypeExpression<?>]) {
			val sndArgValues = sndArgCandidates.map[(it as LiteralTypeExpression<?>).eval()];
			if(sndArgValues.forall[it instanceof Long && (it as Long) >= 0]) {
				val sndArgValue = sndArgValues.filter(Long).max;
				return Optional.of(new TypeConstructorType(null, types.head.typeArguments.head, #[
					new LiteralNumberType(null, sndArgValue, sndArgCandidates.head.castOrNull(LiteralTypeExpression).typeOf) -> Variance.COVARIANT
				]))
			}
		}			
		

		return Optional.absent;
	}		
	
}