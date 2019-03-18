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

import com.google.inject.Inject
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.ExpressionsFactory
import org.eclipse.mita.base.types.ComplexType
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.SumType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.ExpressionStatement
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.generator.internal.GeneratorRegistry
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.mita.base.types.VirtualFunction
import org.eclipse.mita.base.types.GeneratedTypeConstructor
import org.eclipse.mita.base.types.TypeConstructor
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.base.types.TypeAccessor
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.base.expressions.AssignmentExpression

class UnravelFunctionCallsStage extends AbstractUnravelingStage {
	
	@Inject
	protected GeneratorRegistry generatorRegistry
	
	override protected needsUnraveling(Expression expression) {
		// unraveling fails right now if expression is part of a global initialization. 
		// The statement generator can recover for direct initialization (x = foo()), so we don't unravel here.
		// this might lead to invalid code, since unraveling fixes nested expressions like foo() && bar(), however unraveling leads to just as invalid code.
		if(EcoreUtil2.getContainerOfType(expression, ProgramBlock) === null) {
			return false;
		}
		val parent = expression.eContainer;
		// we would unravel expressions into a variable declaration/assignment anyway.
		if(	parent instanceof VariableDeclaration
		 || (parent instanceof AssignmentExpression && parent.eContainer instanceof ExpressionStatement)
		) {
			return false;
		}
		if(expression instanceof NewInstanceExpression) {
			return false;
		}
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
				
				val inferenceResult = BaseUtils.getType(ref);
				if(inferenceResult?.name == 'void') {
					// don't unravel void function calls
					return false;
				}
				
				if(expression.eContainer instanceof ExpressionStatement) {
					// don't unravel function calls made as standalone expression (not part of an assignment/call/condition)
					return false;
				}
				
				if(ref instanceof VirtualFunction) {
					if(ref instanceof TypeConstructor && !(ref instanceof GeneratedTypeConstructor)) {
						return false;
					}
					if(ref instanceof TypeAccessor) {
						return false;
					}
					return true;
				}
				return true;
			}
			
			return false;
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