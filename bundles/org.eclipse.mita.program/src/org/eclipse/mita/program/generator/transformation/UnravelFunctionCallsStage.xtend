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
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.ExpressionStatement
import org.eclipse.mita.base.expressions.ExpressionsFactory
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.GeneratedFunctionDefinition
import org.eclipse.mita.base.types.GeneratedTypeConstructor
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.TypeAccessor
import org.eclipse.mita.base.types.TypeConstructor
import org.eclipse.mita.base.types.VirtualFunction
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.ReturnValueExpression
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.generator.internal.GeneratorRegistry
import org.eclipse.mita.program.generator.internal.ProgramCopier
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.mita.program.ForEachStatement
import org.eclipse.mita.program.AbstractLoopStatement
import org.eclipse.emf.ecore.util.EcoreUtil

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
		
		if(expression instanceof ElementReferenceExpression) {
			val ref = expression.reference;
			
			if(ref instanceof Operation) {
				val parent = expression.eContainer;
				// special case: for generated functions we need to ask the generator if the call should be unraveled.
				if(ref instanceof GeneratedFunctionDefinition) {
					val generator = generatorRegistry.getGenerator(ref);
					if(generator !== null) {
						return generator.callShouldBeUnraveled(expression);
					}
				}
				
				// don't unravel void function calls, since they can't be used as arguments anyway
				// and we can't declare a variable of their result type void
				val typeOfExpression = BaseUtils.getType(ProgramCopier.getOrigin(expression));
				if(typeOfExpression?.name == 'void') {
					// don't unravel void function calls
					return false;
				}

				if(parent instanceof ReturnValueExpression) {
					// don't unravel direct returns
					return false;
				}

				// we would unravel expressions into a variable declaration/assignment anyway.
				if(	parent instanceof VariableDeclaration) {
					// variable declarations are safe, unless they are loop variables.
					return parent.eContainer instanceof AbstractLoopStatement;
				} else if((parent instanceof AssignmentExpression && parent.eContainer instanceof ExpressionStatement && parent.eContainer.eContainer instanceof ProgramBlock)) {
					return false;
				}

				// some virtual functions can be translated to expressions
				if(ref instanceof VirtualFunction) {
					if(ref instanceof TypeConstructor && !(ref instanceof GeneratedTypeConstructor)) {
						return false;
					}
					if(ref instanceof TypeAccessor) {
						return false;
					}
				}
				
				if(expression.eContainer instanceof ExpressionStatement) {
					// do unravel function calls made as standalone expression (not part of an assignment/call/condition),
					// since we can't pass in null pointers, since the function will try to assign it
					return true;
				}
				if(expression.eContainer instanceof AssignmentExpression) {
					// don't unravel function calls made as standalone assignments,
					// since we we would transform to the exact same thing
					return true;
				}
				
				// unravel all operations that are not generated, void, virtual or top level.
				return true;
			}
			// don't unravel variable references
			return false;
		}
		// don't unravel by default
		return false;
	}
	
	override protected createInitialization(Expression expression) {
		if(expression instanceof ElementReferenceExpression) {
			val newFunctionCall = ExpressionsFactory.eINSTANCE.createElementReferenceExpression;
			newFunctionCall.reference = expression.reference;
			newFunctionCall.operationCall = true;
			newFunctionCall.arguments.addAll(expression.arguments);
			return newFunctionCall;			
		}
		else {
			return EcoreUtil.copy(expression);
		}
		
	}
	
}