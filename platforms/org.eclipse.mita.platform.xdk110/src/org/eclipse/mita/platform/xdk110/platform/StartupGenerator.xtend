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

import org.eclipse.mita.platform.Platform
import org.eclipse.mita.program.SystemEventSource
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IPlatformStartupGenerator
import com.google.inject.Inject

class StartupGenerator implements IPlatformStartupGenerator {
	
	@Inject
	protected extension GeneratorUtils
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	override generateMain(CompilationContext context) {
		val systemEvents = context.allEventHandlers.filter[x | x.event instanceof SystemEventSource].filter[x | (x.event as SystemEventSource).origin instanceof Platform ]
		val startupEvent = systemEvents.findFirst[x | (x.event as SystemEventSource).source.name == 'startup' ]
		
		codeFragmentProvider.create('''
		/* Mapping Default Error Handling function */
		Retcode_T returnValue = Retcode_initialize(DefaultErrorHandlingFunc);
		if (RETCODE_OK == returnValue)
		{
		    returnValue = systemStartup();
		}
		if (RETCODE_OK == returnValue)
		{
			returnValue = CmdProcessor_Initialize(&Mita_EventQueue, (char *) "EventQueue", TASK_PRIO_EVENT_LOOP, TASK_STACK_SIZE_EVENT_LOOP, TASK_Q_LEN_EVENT_LOOP);
		}
		if (RETCODE_OK == returnValue)
		{
			returnValue = CmdProcessor_Enqueue(&Mita_EventQueue, Mita_initialize, NULL, UINT32_C(0));
		}
		if (RETCODE_OK == returnValue)
		{
		    returnValue = CmdProcessor_Enqueue(&Mita_EventQueue, Mita_goLive, NULL, UINT32_C(0));
		}
		«IF startupEvent !== null»
		if (RETCODE_OK == returnValue)
		{
			returnValue = CmdProcessor_Enqueue(&Mita_EventQueue, «startupEvent.handlerName», NULL, UINT32_C(0));
		}
		«ENDIF»
		if (RETCODE_OK != returnValue)
		{
		    printf("System Startup failed");
		    assert(false);
		}
		/* start scheduler */
		vTaskStartScheduler();
		''')
		.setPreamble('''
		
		CmdProcessor_T Mita_EventQueue;
		
		/**
		 * The priority of the event loop task. The default of 1 is just above the idle task
		 * priority. Note that the platform may use tasks of higher prio, but XDK LIVE programs
		 * are solely executed in this event loop context.
		 */
		#define TASK_PRIO_EVENT_LOOP         (UINT32_C(1))
		
		/**
		 * The stack size of the event loop task in 32-bit words. If you don't know what this
		 * means, be careful when you change this value. More information can be found here:
		 * http://www.freertos.org/FAQMem.html#StackSize
		 */
		#define TASK_STACK_SIZE_EVENT_LOOP   (UINT16_C(700))
		
		/**
		 * The maximum number of events the event queue can hold. The default value should
		 * be sufficient in most cases. If you need to handle a lot of events and have some
		 * long running computations, you might want to increase this number if you find
		 * events are missed.
		 */
		#define TASK_Q_LEN_EVENT_LOOP        (UINT32_C(10))
		
		''')
		.addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
		.addHeader('FreeRTOS.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('timers.h', true)
		.addHeader('XdkSystemStartup.h', true)
		.addHeader("BCDS_CmdProcessor.h", true)
		.addHeader("stdio.h", true)
	}
	
}