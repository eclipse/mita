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

class ServalPALGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject(optional=true)
	protected IPlatformLoggingGenerator loggingGenerator
	
	
		override generateSetup() {
		
			codeFragmentProvider.create('''
			
			 /**< Handle for Serval PAL thread command processor */
			 static CmdProcessor_T ServalPALCmdProcessorHandle;

			 retcode = CmdProcessor_Initialize(&ServalPALCmdProcessorHandle, "Serval PAL", TASK_PRIORITY_SERVALPAL_CMD_PROC, TASK_STACK_SIZE_SERVALPAL_CMD_PROC, TASK_QUEUE_LEN_SERVALPAL_CMD_PROC);
			
			if (RETCODE_OK == retcode)
			{
				retcode = ServalPal_Initialize(&ServalPALCmdProcessorHandle	);
			}
			
			if (RETCODE_OK == retcode)
			{
				retcode = ServalPalWiFi_Init();
			}

		''')
		.setPreamble('''
				#define TASK_PRIORITY_SERVALPAL_CMD_PROC            UINT32_C(3)
				#define TASK_STACK_SIZE_SERVALPAL_CMD_PROC          UINT32_C(600)
				#define TASK_QUEUE_LEN_SERVALPAL_CMD_PROC           UINT32_C(10)
		''')
		.addHeader("BCDS_ServalPalWiFi.h", true, IncludePath.HIGH_PRIORITY)
		.addHeader("BCDS_ServalPal.h", true, IncludePath.HIGH_PRIORITY)
	}
	
	
	
	override generateEnable() {
			 codeFragmentProvider.create('''
					
					if(RETCODE_OK == retcode)
					{
						retcode = ServalPalWiFi_NotifyWiFiEvent(SERVALPALWIFI_CONNECTED, NULL);
					}

					if(RETCODE_OK != retcode)
					{
						return retcode;
					}
							
					''')
					
					.addHeader("BCDS_ServalPalWiFi.h", true, IncludePath.HIGH_PRIORITY)
					.addHeader("BCDS_ServalPal.h", true, IncludePath.HIGH_PRIORITY)
		}
}
