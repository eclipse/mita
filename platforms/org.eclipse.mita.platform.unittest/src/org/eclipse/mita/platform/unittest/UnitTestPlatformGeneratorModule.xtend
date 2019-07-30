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

package org.eclipse.mita.platform.unittest

import com.google.inject.Inject
import org.eclipse.mita.base.types.Type
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.EmptyPlatformGeneratorModule
import org.eclipse.mita.program.generator.IPlatformExceptionGenerator

class UnitTestPlatformGeneratorModule extends EmptyPlatformGeneratorModule {

	static class ExceptionGenerator implements IPlatformExceptionGenerator {

		@Inject
		CodeFragmentProvider code

		public static val EXCEPTION_TYPE = "int32_t"
		public static val NO_EXCEPTION = "0"

		override generateExceptionCodeFor(CompilationContext context, Type exception) {
			code.create('''0''')
		}

		override generateRaiseException(CompilationContext context, String exceptionVariableName) {
			CodeFragment.EMPTY
		}

		override getExceptionType() {
			code.create('''«EXCEPTION_TYPE»''').addHeader("stdint.h", true);
		}

		override getNoExceptionStatement() {
			code.create('''«NO_EXCEPTION»''').addHeader("stdint.h", true);
		}

	}

	override bindIPlatformExceptionGenerator() {
		ExceptionGenerator
	}

	override bindPlatformBuildSystemGenerator() {
		MakefileGenerator
	}
}
