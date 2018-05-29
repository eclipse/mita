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

package org.eclipse.mita.program.generator.transformation

import org.eclipse.mita.base.expressions.BinaryExpression
import org.eclipse.mita.base.expressions.Expression
import org.eclipse.mita.base.expressions.ExpressionsFactory

class EnforceOperatorPrecedenceStage extends AbstractTransformationStage {
	
	override getOrder() {
		ORDER_VERY_LATE
	}
	
	dispatch def doTransform(BinaryExpression expression) {
		if(expression.leftOperand instanceof BinaryExpression) {
			expression.leftOperand = expression.leftOperand.wrapInParanthesis();
		}
		if(expression.rightOperand instanceof BinaryExpression) {
			expression.rightOperand = expression.rightOperand.wrapInParanthesis();
		}
		
		expression.transformChildren();
	}
	
	def Expression wrapInParanthesis(Expression expression) {
		val result = ExpressionsFactory.eINSTANCE.createParenthesizedExpression();
		result.expression = expression;
		return result;
	}
	
}