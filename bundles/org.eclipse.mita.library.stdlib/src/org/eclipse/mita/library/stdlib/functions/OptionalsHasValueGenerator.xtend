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

import org.eclipse.mita.library.stdlib.OptionalGenerator.enumOptional
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.StatementGenerator
import com.google.inject.Inject
import org.eclipse.mita.base.expressions.ElementReferenceExpression

class OptionalsHasValueGenerator extends AbstractFunctionGenerator {
	
	
	@Inject 
	protected extension StatementGenerator
	
	override generate(ElementReferenceExpression functionCall, String resultVariableName) {
		val args = functionCall.arguments;
		val optVarOrExpr = args.head.value;
				
		codeFragmentProvider.create('''«IF resultVariableName !== null && !resultVariableName.empty»«resultVariableName» = «ENDIF»«optVarOrExpr.code».flag == «enumOptional.Some.name»;''').addHeader('MitaGeneratedTypes.h', false);
	}
	
	
}