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

package org.eclipse.mita.platform.xdk110.connectivity

import com.google.inject.Inject
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator.LogLevel
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer.SumTypeRepr

class ServalPALGenerator {
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject(optional=true)
	protected IPlatformLoggingGenerator loggingGenerator
	
	
		def generateSetup(boolean isSecure) {
		
			codeFragmentProvider.create('''
			
			/**< Handle for Serval PAL thread command processor */
			static CmdProcessor_T ServalPALCmdProcessorHandle;

			exception = CmdProcessor_Initialize(&ServalPALCmdProcessorHandle, "Serval PAL", TASK_PRIORITY_SERVALPAL_CMD_PROC, TASK_STACK_SIZE_SERVALPAL_CMD_PROC, TASK_QUEUE_LEN_SERVALPAL_CMD_PROC);
			
			if (RETCODE_OK == exception)
			{
				exception = ServalPal_Initialize(&ServalPALCmdProcessorHandle);
			}
			if (RETCODE_OK == exception)
			{
				exception = ServalPalWiFi_Init();
			}

		''')
		.setPreamble('''
			#define TASK_PRIORITY_SERVALPAL_CMD_PROC            UINT32_C(3)
			#define TASK_STACK_SIZE_SERVALPAL_CMD_PROC          UINT32_C(«IF isSecure»2000«ELSE»600«ENDIF»)
			#define TASK_QUEUE_LEN_SERVALPAL_CMD_PROC           UINT32_C(10)
		''')
		.addHeader("BCDS_ServalPalWiFi.h", true, IncludePath.HIGH_PRIORITY)
		.addHeader("BCDS_ServalPal.h", true, IncludePath.HIGH_PRIORITY)
	}
	
	
	
	def generateEnable() {
			 codeFragmentProvider.create('''

				if(RETCODE_OK == exception)
				{
					exception = ServalPalWiFi_NotifyWiFiEvent(SERVALPALWIFI_CONNECTED, NULL);
				}

				if(RETCODE_OK != exception)
				{
					return exception;
				}
				
			''')
			.addHeader("BCDS_ServalPalWiFi.h", true, IncludePath.HIGH_PRIORITY)
			.addHeader("BCDS_ServalPal.h", true, IncludePath.HIGH_PRIORITY)
		}
}
