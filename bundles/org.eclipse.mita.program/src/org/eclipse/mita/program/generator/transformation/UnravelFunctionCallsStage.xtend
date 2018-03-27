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

import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.generator.internal.GeneratorRegistry
import org.eclipse.mita.types.GeneratedType
import org.eclipse.mita.types.SumType
import com.google.inject.Inject
import org.yakindu.base.expressions.expressions.ElementReferenceExpression
import org.yakindu.base.expressions.expressions.Expression
import org.yakindu.base.expressions.expressions.ExpressionsFactory
import org.yakindu.base.types.ComplexType
import org.yakindu.base.types.Operation
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.ExpressionStatement

class UnravelFunctionCallsStage extends AbstractUnravelingStage {
	
	@Inject
	protected GeneratorRegistry generatorRegistry
	
	override protected needsUnraveling(Expression expression) {
		if(expression instanceof ElementReferenceExpression) {
			val ref = expression.reference;
			
			if(ref instanceof Operation) {
				// special case: for generated functions we need to ask the generator if the call should be unraveled.
				if(ref instanceof GeneratedFunctionDefinition) {
					val generator = generatorRegistry.getGenerator(ref);
					if(generator !== null) {
						return generator.callShouldBeUnraveled(expression);
					}
				}
				
				val inferenceResult = typeInferrer.infer(ref);
				if(inferenceResult?.type?.name == 'void') {
					// don't unravel void function calls
					return false;
				}
				
				if(expression.eContainer instanceof ExpressionStatement) {
					// don't unravel function calls made as standalone expression (not part of an assignment/call/condition)
					return false;
				}
				
				return true;
			}
			
			return (ref instanceof ComplexType && !(ref instanceof SumType)) 
				|| ref instanceof GeneratedType
		}
		
		return false;
	}
	
	override protected createInitialization(Expression expression) {
		// We can safely make this cast as needsUnraveling ensures that expression must be an ERE
		val elementReferenceExpression = expression as ElementReferenceExpression;
		
		val newFunctionCall = ExpressionsFactory.eINSTANCE.createElementReferenceExpression;
		newFunctionCall.reference = elementReferenceExpression.reference;
		newFunctionCall.operationCall = true;
		newFunctionCall.arguments.addAll(elementReferenceExpression.arguments);
		return newFunctionCall;
	}
	
}