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

package org.eclipse.mita.program.generator.internal

import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IPlatformExceptionGenerator
import com.google.inject.Inject

class ExceptionGenerator {
	
	@Inject
	protected extension GeneratorUtils
	
	@Inject(optional = true)
	protected IPlatformExceptionGenerator exceptionGenerator

    @Inject
    protected CodeFragmentProvider codeFragmentProvider

	def generateHeader(CompilationContext context) {
		
		
		return codeFragmentProvider.create('''
			#define NO_EXCEPTION «exceptionGenerator.noExceptionStatement»

			«FOR exception : context.allExceptionsUsed»
			#define «exception.baseName» «exceptionGenerator.generateExceptionCodeFor(context, exception)»
			«ENDFOR»
		''')
		.toHeader(context, 'MITA_EXCEPTIONS_H')
	}
	
}