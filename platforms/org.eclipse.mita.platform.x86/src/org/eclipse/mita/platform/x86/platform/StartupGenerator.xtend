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
 
package org.eclipse.mita.platform.x86.platform

import org.eclipse.mita.program.generator.IPlatformStartupGenerator
import org.eclipse.mita.program.generator.CompilationContext
import com.google.inject.Inject
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.TimeIntervalEvent
import org.eclipse.mita.program.model.ModelUtils

class StartupGenerator implements IPlatformStartupGenerator {
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject 
	protected extension GeneratorUtils
	
	override generateMain(CompilationContext context) {
		return codeFragmentProvider.create('''
			Mita_initialize();
			Mita_goLive();
			while(1) {
				int32_t now = getTime();
				«FOR handler : context.allEventHandlers»
				«val evt = handler.event»
				«IF evt instanceof TimeIntervalEvent»
					«val period = ModelUtils.getIntervalInMilliseconds(evt)»
					if(now - lastTick«period.toString.toFirstUpper» >= «period.toString») {
						lastTick«period.toString.toFirstUpper» += «period.toString»;
						«evt.handlerName»();
						fflush(stdout);
					}
				«ELSE»
					if(«handler.handlerName»_flag) {
						«handler.handlerName»_flag = false;
						«evt.handlerName»();
					}
				«ENDIF»
				«ENDFOR»
				sleepMs(5);
			}
			return 0;
		''')
		.addHeader('time.h', true)
		.addHeader('stdio.h', true)
		.addHeader('stdbool.h', true);
	}

}
