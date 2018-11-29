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

package org.eclipse.mita.program.generator

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.xtext.generator.trace.node.IGeneratorNode

/**
 * Generates code implementing a function call. 
 */
abstract class AbstractFunctionGenerator implements IGenerator {

	@Inject
	protected StatementGenerator statementGenerator;
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider;
	
	/**
	 * Generates code from a function application and stores the result in a variable named resultVariableName.
	 * If resultVariableName is null the generator is expected to produce a valid C expression. If the generator
	 * cannot produce such an expression it should mark an error.
	 */
	abstract def CodeFragment generate(ElementReferenceExpression functionCall, IGeneratorNode resultVariableName)
	
	/**
	 * This function allows generators to opt out of the regular function unraveling. This enables function generators
	 * to produce more optimized code compared to using the intermediate variables produced by the unraveling process.
	 * 
	 * The default implementation returns true here, which means that the function call will be unraveled (unless the function's return type is void).
	 */
	def boolean callShouldBeUnraveled(ElementReferenceExpression expression) {
		val inferenceResult = BaseUtils.getType(expression?.reference);
		if(inferenceResult?.name == 'void') {
			// don't unravel void function calls
			return false;
		} else {
			return true;
		}
	}
	
	protected def generate(EObject obj) {
		return if(obj === null) null else statementGenerator.code(obj);
	}
	
}