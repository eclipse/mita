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

import java.util.HashSet
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.InterpolatedStringLiteral
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.generator.internal.ProgramCopier
import org.eclipse.xtext.EcoreUtil2

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull

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
		
		return possibleFunctionCallContainer !== null 
			&& possibleFunctionCallContainer?.isOperationCall 
			&& !isInPrintContext 
			&& expression.castOrNull(PrimitiveValueExpression)?.value?.castOrNull(InterpolatedStringLiteral) !== null;
	}
	
	override protected createInitialization(Expression expression) {
		// safe cast since ~3lines above we return true only if expression is a primitive value expression and since super copies the expression
		val copy = super.createInitialization(expression) as PrimitiveValueExpression;
		val original = expression as PrimitiveValueExpression;
		// link inner value
		ProgramCopier.linkOrigin(copy.value, ProgramCopier.getOrigin(original.value));
		return copy;
	}
}