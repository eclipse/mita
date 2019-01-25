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

import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.InterpolatedStringExpression
import org.eclipse.xtext.EcoreUtil2
import java.util.HashSet

class UnravelInterpolatedStringsStage extends AbstractUnravelingStage {
	
	override protected needsUnraveling(Expression expression) {
		val printContextFunctionNames = new HashSet(#[
			'print',
			'println',
			'logDebug',
			'logInfo',
			'logWarning',
			'logError'
		]);
		
		var isInPrintContext = false;
		val possibleFunctionCallContainer = EcoreUtil2.getContainerOfType(expression, ElementReferenceExpression);
		if(possibleFunctionCallContainer !== null) {
			val funName = BaseUtils.getText(possibleFunctionCallContainer, ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference);
			if(printContextFunctionNames.contains(funName)) {
				isInPrintContext = true;
			}
		}
		
		return possibleFunctionCallContainer !== null && possibleFunctionCallContainer?.isOperationCall && !isInPrintContext && (expression instanceof InterpolatedStringExpression);
	}
	
}