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

import com.google.inject.Inject
import java.util.Optional
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.library.stdlib.RingbufferGenerator
import org.eclipse.mita.library.stdlib.RingbufferGenerator.PushGenerator
import org.eclipse.mita.program.SystemEventSource
import org.eclipse.mita.program.TimeIntervalEvent
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CodeWithContext
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IPlatformStartupGenerator
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry

class StartupGenerator implements IPlatformStartupGenerator {
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject 
	protected extension GeneratorUtils
	
	@Inject
	protected PushGenerator pushGenerator
	
	@Inject
	StdlibTypeRegistry typeRegistry
	
	override generateMain(CompilationContext context) {
		val startupEventHandlersAndEvents = context.allEventHandlers
			.map[it -> it.event]
			.filter[it.value instanceof SystemEventSource]
			.map[it.key -> it.value as SystemEventSource]
			.filter[it.value.source.name == "startup"]
		return codeFragmentProvider.create('''
			Mita_initialize();
			Mita_goLive();
			int32_t exception = 0;
			«FOR startupEventHandler_event: startupEventHandlersAndEvents»
				«val startupEventHandler = startupEventHandler_event.key»
				«val event = startupEventHandler_event.value»
				«pushGenerator.generate(
					startupEventHandler,
					new CodeWithContext(
						RingbufferGenerator.wrapInRingbuffer(typeRegistry, startupEventHandler, BaseUtils.getType(event)), 
						Optional.empty, 
						codeFragmentProvider.create('''rb_«startupEventHandler.handlerName»''')
					),
					codeFragmentProvider.create('''getTime()''')
				)»
			«ENDFOR»
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
		.setPreamble('''
			«FOR startupEventHandler_event: startupEventHandlersAndEvents»					
				extern ringbuffer_uint32_t rb_«startupEventHandler_event.key.handlerName»;
			«ENDFOR»
		''')
		.addHeader('time.h', true)
		.addHeader('stdio.h', true)
		.addHeader('stdbool.h', true)
		.addHeader("MitaEvents.h", false);
	}

}
