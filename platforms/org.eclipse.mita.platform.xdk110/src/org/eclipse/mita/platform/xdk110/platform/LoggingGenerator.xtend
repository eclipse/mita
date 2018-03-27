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

package org.eclipse.mita.platform.xdk110.platform

import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator
import com.google.inject.Inject

class LoggingGenerator implements IPlatformLoggingGenerator {
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider;
	
	override generateLogStatement(LogLevel level, String pattern, CodeFragment... values) {
		val myValues = #['__FILE__', '__LINE__'] + values
		codeFragmentProvider.create('''printf("[«level.name.toUpperCase», %s:%d] «pattern»\n", «FOR v : myValues SEPARATOR ', '»«v»«ENDFOR»);
		''')
		.addHeader('inttypes.h', true)
	}
	
}