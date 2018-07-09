/********************************************************************************
 * Copyright (c) 2018 itemis AG.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    itemis AG - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/
 
package org.eclipse.mita.platform.arduino.uno.platform

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
		return CodeFragment.EMPTY
	}

	override generateRaiseException(CompilationContext context, String exceptionVariableName) {
		return CodeFragment.EMPTY
	}

	override getExceptionType() {
		return codeFragmentProvider.create('''Exception_T''').addHeader("Retcode.h", false);
	}

	override getNoExceptionStatement() {
		return codeFragmentProvider.create('''STATUS_OK''').addHeader("Retcode.h", false);
	}
	
}
