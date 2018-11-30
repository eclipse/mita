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

import org.eclipse.mita.program.generator.transformation.AbstractUnravelingStage
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.ArrayLiteral
import org.eclipse.mita.base.expressions.Argument
import org.eclipse.mita.base.expressions.FeatureCall

class UnravelLiteralArraysStage extends AbstractUnravelingStage {
	
	override protected needsUnraveling(Expression expression) {
		if(expression instanceof PrimitiveValueExpression) {
			if(expression.value instanceof ArrayLiteral) {
				val container = expression.eContainer;
				return container instanceof ReturnStatement || container instanceof Argument || container instanceof FeatureCall
			}
		}
		return false;
	}

}