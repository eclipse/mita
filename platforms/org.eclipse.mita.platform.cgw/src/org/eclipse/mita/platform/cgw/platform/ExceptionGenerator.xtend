/********************************************************************************
 * Copyright (c) 2019 Robert Bosch GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/
 
package org.eclipse.mita.platform.cgw.platform

import com.google.inject.Inject
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.IPlatformExceptionGenerator
import org.eclipse.mita.base.types.Type

class ExceptionGenerator implements IPlatformExceptionGenerator {
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	override generateExceptionCodeFor(CompilationContext context, Type exception) {
		val exceptionName = '''EXCEPTION_«exception.name.toUpperCase»''';
		val exceptionValue = Math.abs(exceptionName.hashCode);
		
		return codeFragmentProvider.create('''RETCODE(RETCODE_SEVERITY_ERROR, UINT32_C(«exceptionValue»))''')
			.addHeader('BCDS_Retcode.h', true);
	}
	
	override getExceptionType() {
		return codeFragmentProvider.create('''Retcode_T''').addHeader("BCDS_Retcode.h", true);
	}
	
	override getNoExceptionStatement() {
		return codeFragmentProvider.create('''RETCODE_OK''')
			.setPreamble('''
			#ifndef BCDS_MODULE_ID
			#define BCDS_MODULE_ID 0xCAFE
			#endif
			''')
			.addHeader("BCDS_Retcode.h", true);
	}
	
	override generateRaiseException(CompilationContext context, String exceptionVariableName) {
		return codeFragmentProvider.create('''Retcode_raiseError(«exceptionVariableName»);''').addHeader('BCDS_Retcode.h', true);
	}
	
}