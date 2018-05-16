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

package org.eclipse.mita.program.inferrer

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.program.ValueRange
import org.eclipse.mita.program.VariableDeclaration
import org.yakindu.base.expressions.expressions.BoolLiteral
import org.yakindu.base.expressions.expressions.DoubleLiteral
import org.yakindu.base.expressions.expressions.ElementReferenceExpression
import org.yakindu.base.expressions.expressions.Expression
import org.yakindu.base.expressions.expressions.FloatLiteral
import org.yakindu.base.expressions.expressions.IntLiteral
import org.yakindu.base.expressions.expressions.NumericalUnaryExpression
import org.yakindu.base.expressions.expressions.PrimitiveValueExpression
import org.yakindu.base.expressions.expressions.StringLiteral
import org.yakindu.base.types.Enumerator

/**
 * Infers the value of an expression at compile time.
 */
class StaticValueInferrer {
	
	static dispatch def Object infer(BoolLiteral expression, (EObject) => void inferenceBlockerAcceptor) {
		return expression.value;
	} 
	
	static dispatch def Object infer(DoubleLiteral expression, (EObject) => void inferenceBlockerAcceptor) {
		return expression.value;
	}
	
	static dispatch def Object infer(FloatLiteral expression, (EObject) => void inferenceBlockerAcceptor) {
		return expression.value;
	}
	
	static dispatch def Object infer(StringLiteral expression, (EObject) => void inferenceBlockerAcceptor) {
		return expression.value;
	}
	
	static dispatch def Object infer(IntLiteral expression, (EObject) => void inferenceBlockerAcceptor) {
		return expression.value;
	}
	
	static dispatch def Object infer(Enumerator expression, (EObject) => void inferenceBlockerAcceptor) {
		return expression;
	}
		
	static dispatch def Object infer(NumericalUnaryExpression expression, (EObject) => void inferenceBlockerAcceptor) {
		val inner = expression.operand.infer(inferenceBlockerAcceptor);
		if(inner === null || !(inner instanceof Integer || inner instanceof Float)) {
			return null;
		}
		val op = expression.operator;
		switch(op) {
			case NEGATIVE:
				if(inner instanceof Integer) {
					return (-1) * inner;	
				} else if(inner instanceof Float) {
					return (-1) * inner;	
				}
		}
		
		return null;
	}
	
	static dispatch def Object infer(PrimitiveValueExpression expression, (EObject) => void inferenceBlockerAcceptor) {
		return expression.value.infer(inferenceBlockerAcceptor);
	}
	
	static dispatch def Object infer(ElementReferenceExpression expression, (EObject) => void inferenceBlockerAcceptor) {
		return expression.reference?.infer(inferenceBlockerAcceptor);
	}
	
	static dispatch def Object infer(VariableDeclaration expression, (EObject) => void inferenceBlockerAcceptor) {
		if(expression.writeable) {
			inferenceBlockerAcceptor.apply(expression);
			return null;
		} else {
			return expression.initialization?.infer(inferenceBlockerAcceptor);
		}
	}
		
	static dispatch def Object infer(ValueRange expression, (EObject) => void inferenceBlockerAcceptor) {
		val lower = expression.lowerBound?.infer(inferenceBlockerAcceptor);
		if(expression.lowerBound !== null && lower === null) return null;
		val upper = expression.upperBound?.infer(inferenceBlockerAcceptor);
		if(expression.upperBound !== null && upper === null) return null;
		return #[lower, upper];
	}
	
	static dispatch def Object infer(Void expression, (EObject) => void inferenceBlockerAcceptor) {
		inferenceBlockerAcceptor.apply(null);
		return null;
	}
	
	static dispatch def Object infer(Expression expression, (EObject) => void inferenceBlockerAcceptor) {
		inferenceBlockerAcceptor.apply(expression);
		return null;
	}
	
	static dispatch def Object infer(EObject expression, (EObject) => void inferenceBlockerAcceptor) {
		inferenceBlockerAcceptor.apply(expression);
		return null;
	}
}