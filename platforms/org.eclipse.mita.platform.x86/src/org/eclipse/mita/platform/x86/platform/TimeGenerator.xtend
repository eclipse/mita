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

import org.eclipse.mita.program.generator.IPlatformTimeGenerator
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import com.google.inject.Inject
import org.eclipse.mita.program.TimeIntervalEvent
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.generator.IPlatformEventLoopGenerator
import org.eclipse.mita.program.generator.GeneratorUtils

class TimeGenerator implements IPlatformTimeGenerator {

	@Inject
	protected extension CodeFragmentProvider codeFragmentProvider

	@Inject
	protected IPlatformEventLoopGenerator eventLoopGenerator

	@Inject
	protected extension GeneratorUtils
	
	override generateTimeEnable(CompilationContext context, EventHandlerDeclaration handler) {
		return codeFragmentProvider.create('''Time_Enable();''')
	}

	override generateTimeGoLive(CompilationContext context) {
		return CodeFragment.EMPTY
	}

	override generateTimeSetup(CompilationContext context) {
		
		val body = codeFragmentProvider.create('''
			return 0;
		''')

		return codeFragmentProvider.create(body).setPreamble('''	
			int32_t Time_Enable(void) {
				«FOR handler : context.allTimeEvents»
					«val period = ModelUtils.getIntervalInMilliseconds(handler.event as TimeIntervalEvent)»
					lastTick«period.toString.toFirstUpper» = clock();
				«ENDFOR»
			}
		''')
		.addHeader('time.h', true)
		.addHeader('MitaExceptions.h', false)
		.addHeader('MitaEvents.h', false);
	}
	
}
