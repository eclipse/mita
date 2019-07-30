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
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.GeneratorUtils

class MainGenerator extends AbstractSystemResourceGenerator {
	@Inject
	protected extension GeneratorUtils
	
	def getResourcesUsed() {
		return context.resourceGraph.nodes
			.filter[it instanceof AbstractSystemResource || it instanceof SystemResourceSetup]
			.map[
				if(it instanceof AbstractSystemResource) {
					it.name;
				}
				else if(it instanceof SystemResourceSetup) {
					it.type?.name;
				}
			]
	}
	
	def isI2cTranceiverSetupNeeded() {
		return resourcesUsed.exists[#["accelerometer", "environment"].exists[name | name == it]];
	}
	
	override generateSetup() {
		val consoleInterface = configuration.getEnumerator("consoleInterface")?.name;
		return codeFragmentProvider.create('''
			Retcode_T exception = NO_EXCEPTION;
			«IF i2cTranceiverSetupNeeded»
			i2cHandle = BSP_BME280_GetHandle(0);
			if(i2cHandle == NULL) {
				i2cHandle = BSP_BMA280_GetHandle(0);
			}
			if(i2cHandle == NULL) {
				return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_NULL_POINTER);
			}
			exception = I2CTransceiver_Init(&i2cTransceiverStruct, i2cHandle);
			«generateExceptionHandler(null, "exception")»
			exception = MCU_I2C_Initialize(i2cHandle, I2CCallback);
			«generateExceptionHandler(null, "exception")»
			«ENDIF»
			exception = Logging_Init(Logging_SyncRecorder, «IF consoleInterface == "RTT"»Logging_RttAppender«ELSE»Logging_UARTAppender«ENDIF»);
		    «generateExceptionHandler(null, "exception")»
			return exception;
		''').setPreamble('''
			«IF i2cTranceiverSetupNeeded»
			static void I2CCallback(I2C_T i2c, struct MCU_I2C_Event_S event) {
				I2CTransceiver_LoopCallback(&i2cTransceiverStruct,  event);
			}
			«ENDIF»

			#undef BCDS_MODULE_ID
			#define BCDS_MODULE_ID 43
			#include "BCDS_Logging.h"

			int _write(int file, char *ptr, int len)
			{
			    char buf[len+1];
				memcpy(buf, ptr, len);
				buf[len] = 0;
				LOG_DEBUG(buf);
				return len;
			}
		''')
		.addHeader("BCDS_BSP_BMA280.h", false)
		.addHeader("BCDS_BSP_BME280.h", false)
		.addHeader("BCDS_MCU_I2C.h", false)
		.addHeader("BCDS_I2CTransceiver.h",	false)
		.addHeader('BCDS_Basics.h', false, IncludePath.VERY_HIGH_PRIORITY)
		.addHeader("BCDS_Retcode.h", false)
	}
	
	override generateAdditionalHeaderContent() {
		return codeFragmentProvider.create('''
			«super.generateAdditionalHeaderContent()»
			«IF i2cTranceiverSetupNeeded»
			I2cTranceiverHandle_T i2cTransceiverStruct;
			I2C_T i2cHandle;
			«ENDIF»
		''')
		.addHeader("BCDS_MCU_I2C.h", false)
		.addHeader("BCDS_I2CTransceiver.h",	false);
	}
	
	override generateEnable() {
		return CodeFragment.EMPTY;
	}
	
}
