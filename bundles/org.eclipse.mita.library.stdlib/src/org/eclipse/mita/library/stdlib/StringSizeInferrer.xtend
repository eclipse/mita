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

import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.expressions.StringLiteral
import org.eclipse.mita.base.types.InterpolatedStringLiteral
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.inferrer.ElementSizeInferenceResult
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult

class StringSizeInferrer extends ArraySizeInferrer {
	
	protected dispatch def ElementSizeInferenceResult doInfer(StringLiteral expression, AbstractType type) {
		return newValidResult(expression, expression.value.length);
	}
	
	protected dispatch override ElementSizeInferenceResult doInfer(PrimitiveValueExpression expression, AbstractType type) {
		return expression.value.infer;
	}

	protected dispatch def ElementSizeInferenceResult doInfer(InterpolatedStringLiteral expr, AbstractType type) {
		expr.isolatedDoInfer
	}
	
	protected dispatch override ElementSizeInferenceResult doInfer(NewInstanceExpression expr, AbstractType type) {
		expr.inferFixedSize
	}
		
	protected def dispatch ElementSizeInferenceResult isolatedDoInfer(StringLiteral expression) {
		newValidResult(expression, expression.value.length);		
	}
	
	protected override dispatch ElementSizeInferenceResult isolatedDoInfer(PrimitiveValueExpression expression) {
		val value = expression.value;
		if(value instanceof StringLiteral) {
			value.isolatedDoInfer;
		} else {
			newInvalidResult(expression, "Cannot infer string length of " + value);
		}
	}
	
	protected def dispatch isolatedDoInfer(InterpolatedStringLiteral expr) {
		var length = expr.sumTextParts
		
		// sum expression value part
		for(subexpr : expr.content) {
			val type = BaseUtils.getType(subexpr);
			var typeLengthInBytes = switch(type?.name) {
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
					val stringSize = super.infer(subexpr);
					if(stringSize instanceof ValidElementSizeInferenceResult) {
						stringSize.elementCount;
					} else {
						// stringSize inference was not valid
						return stringSize;
					}
				}
				default: null
			}
			
			if(typeLengthInBytes === null) {
				return newInvalidResult(subexpr, "Cannot interpolate expressions of type " + type);
			} else {
				length += typeLengthInBytes;
			}
		}

		return newValidResult(expr, length);
	}
		
	protected def long sumTextParts(InterpolatedStringLiteral expr) {
		val texts = StringGenerator.getOriginalTexts(expr)
		if (texts.nullOrEmpty) {
			0
		} else {
			texts.map[x | x.length as long ].reduce[x1, x2| x1 + x2 ];
		}
	}		
	
}