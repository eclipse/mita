/********************************************************************************
 * Copyright (c) 2019 Robert Bosch GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/
 
package org.eclipse.mita.platform.cgw.platform

import com.google.inject.Inject
import org.eclipse.mita.platform.Platform
import org.eclipse.mita.program.SystemEventSource
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IPlatformStartupGenerator

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
		Retcode_T returnValue = Retcode_Initialize(ErrorHandler);
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
		#define TASK_STACK_SIZE_EVENT_LOOP   (UINT16_C(2000))
		
		/**
		 * The maximum number of events the event queue can hold. The default value should
		 * be sufficient in most cases. If you need to handle a lot of events and have some
		 * long running computations, you might want to increase this number if you find
		 * events are missed.
		 */
		#define TASK_Q_LEN_EVENT_LOOP        (UINT32_C(10))
		
		/**
		 * @brief This function is SysTick Handler.
		 * This is called when ever the IRQ is hit.
		 * This is a temporary implementation where
		 * the SysTick_Handler() is not directly mapped
		 * to xPortSysTickHandler(). Instead it is only
		 * called if the scheduler has started.
		 */
		static void SysTickPreCallback(void)
		{
		    if (xTaskGetSchedulerState() != taskSCHEDULER_NOT_STARTED)
		    {
		        xPortSysTickHandler();
		    }
		}
		
		void vApplicationGetTimerTaskMemory(StaticTask_t** ppxTimerTaskTCBBuffer, StackType_t** ppxTimerTaskStackBuffer, uint32_t* pulTimerTaskStackSize)
		{
		    /* If the buffers to be provided to the Timer task are declared inside this
		     function then they must be declared static - otherwise they will be allocated on
		     the stack and so not exists after this function exits. */
		    static StaticTask_t xTimerTaskTCB;
		    static StackType_t uxTimerTaskStack[configTIMER_TASK_STACK_DEPTH];
		
		    /* Pass out a pointer to the StaticTask_t structure in which the Timer
		     task's state will be stored. */
		    *ppxTimerTaskTCBBuffer = &xTimerTaskTCB;
		
		    /* Pass out the array that will be used as the Timer task's stack. */
		    *ppxTimerTaskStackBuffer = uxTimerTaskStack;
		
		    /* Pass out the size of the array pointed to by *ppxTimerTaskStackBuffer.
		     Note that, as the array is necessarily of type StackType_t,
		     configTIMER_TASK_STACK_DEPTH is specified in words, not bytes. */
		    *pulTimerTaskStackSize = configTIMER_TASK_STACK_DEPTH;
		}
		void vApplicationGetIdleTaskMemory(StaticTask_t** ppxIdleTaskTCBBuffer, StackType_t** ppxIdleTaskStackBuffer, uint32_t* pulIdleTaskStackSize)
		{
		    /* If the buffers to be provided to the Idle task are declared inside this
		     function then they must be declared static - otherwise they will be allocated on
		     the stack and so not exists after this function exits. */
		    static StaticTask_t xIdleTaskTCB;
		    static StackType_t uxIdleTaskStack[configMINIMAL_STACK_SIZE];
		
		    /* Pass out a pointer to the StaticTask_t structure in which the Idle task's
		     state will be stored. */
		    *ppxIdleTaskTCBBuffer = &xIdleTaskTCB;
		
		    /* Pass out the array that will be used as the Idle task's stack. */
		    *ppxIdleTaskStackBuffer = uxIdleTaskStack;
		
		    /* Pass out the size of the array pointed to by *ppxIdleTaskStackBuffer.
		     Note that, as the array is necessarily of type StackType_t,
		     configMINIMAL_STACK_SIZE is specified in words, not bytes. */
		    *pulIdleTaskStackSize = configMINIMAL_STACK_SIZE;
		}
		
		#ifndef NDEBUG /* valid only for debug builds */
		/**
		 * @brief This API is called when function enters an assert
		 *
		 * @param[in] line : line number where asserted
		 * @param[in] file : file name which is asserted
		 *
		 */
		
		void assertIndicationMapping(const unsigned long line, const unsigned char * const file)
		{
		    /* Switch on the LEDs */
		    Retcode_T retcode = RETCODE_OK;
		
		    retcode = BSP_LED_Switch(COMMONGATEWAY_LED_ALL,COMMONGATEWAY_LED_COMMAND_ON);
		
		    printf("asserted at Filename %s , line no  %ld \n\r", file, line);
		
		    if (retcode != RETCODE_OK)
		    {
		        printf("LED's ON failed during assert");
		    }
		
		}
		#endif
		Retcode_T systemStartup(void)
		{
		    Retcode_T returnValue = RETCODE_OK;
		    uint32_t param1 = 0;
		    void* param2 = NULL;
		
		    /* Initialize the callbacks for the system tick */
		    BSP_Board_OSTickInitialize(SysTickPreCallback, NULL);
		
		#ifndef NDEBUG /* valid only for debug builds */
		    if (RETCODE_OK == returnValue)
		    {
		        returnValue = Assert_Initialize(assertIndicationMapping);
		    }
		#endif
		    /* First we initialize the board. */
		    if (RETCODE_OK == returnValue)
		    {
		        returnValue = BSP_Board_Initialize(param1, param2);
		    }
		    return returnValue;
		}
		void ErrorHandler(Retcode_T error, bool isfromIsr)
		{
		    if (false == isfromIsr)
		    {
		        /** @TODO ERROR HANDLING SHOULD BE DONE FOR THE ERRORS RAISED FROM PLATFORM */
		        uint32_t PackageID = Retcode_GetPackage(error);
		        uint32_t ErrorCode = Retcode_GetCode(error);
		        uint32_t ModuleID = Retcode_GetModuleId(error);
		        Retcode_Severity_T SeverityCode = Retcode_GetSeverity(error);
		
		        if (RETCODE_SEVERITY_FATAL == SeverityCode)
		            printf("Fatal error from package %u , Error code: %u and module ID is :%u \r\n",(unsigned int) PackageID ,(unsigned int) ErrorCode, (unsigned int) ModuleID);
		
		        if (RETCODE_SEVERITY_ERROR == SeverityCode)
		            printf("Severe error from package %u , Error code: %u and module ID is :%u \r\n",(unsigned int) PackageID , (unsigned int) ErrorCode, (unsigned int) ModuleID);
		    }
		    else
		    {
		        BSP_LED_Switch(COMMONGATEWAY_LED_RED_ID, COMMONGATEWAY_LED_COMMAND_ON);
		    }
		}
		''')
		.addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
		.addHeader('FreeRTOS.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('BSP_CommonGateway.h', true)
		.addHeader('timers.h', true)
		.addHeader("BCDS_CmdProcessor.h", true)
		.addHeader("stdio.h", true)
	}
	
}