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

import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.TimeIntervalEvent
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IPlatformEventLoopGenerator
import org.eclipse.mita.program.generator.IPlatformTimeGenerator
import org.eclipse.mita.program.model.ModelUtils
import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject

class TimeGenerator implements IPlatformTimeGenerator {
	
	@Inject
	protected extension GeneratorUtils
	
	@Inject
	protected IPlatformEventLoopGenerator eventLoopGenerator
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	override generateTimeGoLive(CompilationContext context) {
		return CodeFragment.EMPTY
	}
	
	override generateTimeSetup(CompilationContext context) {
		val allTimeEvents = context.allTimeEvents
				
		// prepare the timer creation
		val body = codeFragmentProvider.create('''
		
		«FOR handler : allTimeEvents»
		«val name = handler.timerName»
		«val period = ModelUtils.getIntervalInMilliseconds(handler.event as TimeIntervalEvent)»
		«name» = xTimerCreate("«name»", UINT32_C(«period»), pdTRUE, NULL, «handler.internalHandlerName»);

		«ENDFOR»
		if(«allTimeEvents.map[x | x.event.timerName + ' == NULL'].join(' || ')»)
		{
			return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
		}
		''')
		
		// assemble
		return codeFragmentProvider.create(body).setPreamble('''
				«FOR handler : allTimeEvents»
				static TimerHandle_t «handler.timerName»;
				«ENDFOR»
				
				«FOR handler : allTimeEvents»
				static void «handler.internalHandlerName»(TimerHandle_t xTimer)
				{
					BCDS_UNUSED(xTimer);
					«eventLoopGenerator.generateEventLoopInject(context, handler.handlerName)»
				}
				
				«ENDFOR»''')
			.addHeader('FreeRTOS.h', true, IncludePath.VERY_HIGH_PRIORITY)
			.addHeader('BCDS_Basics.h', true, IncludePath.HIGH_PRIORITY)
			.addHeader('timers.h', true)
			.addHeader('MitaEvents.h', false)
			.addHeader('MitaExceptions.h', false)
			.addHeader('MitaTime.h', false, IncludePath.HIGH_PRIORITY)
			.addHeader('BCDS_CmdProcessor.h', true)
	}
	
	override generateTimeEnable(CompilationContext context, EventHandlerDeclaration handler) {
		return codeFragmentProvider.create('''xTimerStart(«handler.timerName», 0);''')
			.addHeader('timers.h', true);
	}
	
	
	protected def allTimeEvents(CompilationContext context) {
		return context.allEventHandlers.filter[x | x.event instanceof TimeIntervalEvent ]
	}
	
	protected def getTimerName(EObject event) {
		return '''timer«event.handlerName»'''
	}
	
	protected def getInternalHandlerName(EObject event) {
		return '''Internal«event.handlerName.toFirstUpper»'''
	}
	
	
}