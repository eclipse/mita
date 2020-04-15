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

package org.eclipse.mita.library.stdlib.functions

import com.google.inject.Inject
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeWithContext
import org.eclipse.mita.program.generator.StatementGenerator

class ModalityReadGenerator extends AbstractFunctionGenerator {
	
	@Inject
	protected StatementGenerator statementGenerator
	
	override callShouldBeUnraveled(ElementReferenceExpression expression) {
		return false;
	}
	
	override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
		if(resultVariable === null) {
			CodeFragment.EMPTY
		} else {
			codeFragmentProvider.create('''«resultVariable.code» = «statementGenerator.code(functionCall.arguments.get(0).value)»;''');			
		}
	}
	
}