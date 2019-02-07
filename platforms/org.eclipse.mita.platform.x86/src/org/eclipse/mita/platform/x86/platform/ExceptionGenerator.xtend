/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *    itemis AG - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/
 
package org.eclipse.mita.platform.x86.platform

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
		return codeFragmentProvider.create('''int32_t''').addHeader("inttypes.h", true);
	}

	override getNoExceptionStatement() {
		return codeFragmentProvider.create('''0''');
	}
	
}
