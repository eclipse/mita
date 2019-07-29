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

package org.eclipse.mita.platform.cgw.platform

import com.google.inject.Inject
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator

class LoggingGenerator implements IPlatformLoggingGenerator {
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider;
	
	override generateLogStatement(LogLevel level, String pattern, CodeFragment... values) {
		codeFragmentProvider.create('''LOG_«level.name.toUpperCase»("«pattern»\n"«IF !values.empty», «ENDIF»«FOR v : values SEPARATOR ', '»«v»«ENDFOR»);
		''')
		.addHeader('inttypes.h', true)
		.addHeader('BCDS_Logging.h', false)
	}
	
}