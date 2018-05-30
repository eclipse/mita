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
import org.eclipse.mita.base.expressions.Expression
import org.eclipse.mita.program.InterpolatedStringExpression
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.program.GeneratedFunctionDefinition

class UnravelInterpolatedStringsStage extends AbstractUnravelingStage {
	
	override protected needsUnraveling(Expression expression) {
		val printContextFunctionNames = #[
			'print',
			'println',
			'logDebug',
			'logInfo',
			'logWarning',
			'logError'
		];
		
		var isInPrintContext = false;
		val possibleFunctionCallContainer = EcoreUtil2.getContainerOfType(expression, ElementReferenceExpression);
		if(possibleFunctionCallContainer !== null) {
			val ref = possibleFunctionCallContainer.reference;
			if(ref instanceof GeneratedFunctionDefinition) {
				if(printContextFunctionNames.contains(ref.name)) {
					isInPrintContext = true;
				}
			}
		}
		
		return !isInPrintContext && (expression instanceof InterpolatedStringExpression);
	}
	
}