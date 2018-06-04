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

package org.eclipse.mita.platform.xdk110.buses

import com.google.inject.Inject
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.model.ModelUtils

class I2CGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	extension StatementGenerator statementGenerator
	
	@Inject 
	extension GeneratorUtils generatorUtils

	override generateSetup() {
		
		codeFragmentProvider.create('''
		Retcode_T exception = RETCODE_OK;
		
		Board_EnablePowerSupply3V3(EXTENSION_BOARD);
		Board_WakeupPowerSupply2V5(EXTENSION_BOARD);
		
		BSP_Board_Delay(5);
		
		exception = BSP_ExtensionPort_ConnectI2c();
		if(RETCODE_OK != exception) {
			printf("connect failed\n");
			return exception;
		}
		
		handle = BSP_ExtensionPort_GetI2cHandle();
		if(NULL == handle) {
			printf("handle null\n");
			return EXCEPTION_NOVALUEEXCEPTION;
		}
		exception = I2CTransceiver_Init(&tranceiverStruct, handle);
		if(RETCODE_OK != exception) {
			printf("i2ctransceiver_init failed\n");
		}
		
		exception = MCU_I2C_Initialize(handle, &i2cCallback);
		if(RETCODE_OK != exception) {
			printf("MCU_I2C_Initialize failed\n");
			return exception;
		}
				
		exception = BSP_ExtensionPort_EnableI2c();
		
		return exception;
		''')
		.addHeader("BSP_ExtensionPort.h", true)
		.addHeader("BCDS_MCU_I2C.h", true)
		.addHeader("BCDS_I2CTransceiver.h", true)
		.addHeader("FreeRTOS.h", true, 10000)
		.addHeader("semphr.h", true)
		.addHeader("BSP_BoardType.h", true)
		.addHeader("BSP_BoardShared.h", true)
		.setPreamble('''
		static HWHandle_T handle;
		static struct I2cTranceiverHandle_S tranceiverStruct;
		
		static void i2cCallback(I2C_T i2c, struct MCU_I2C_Event_S event) {
			I2CTransceiver_LoopCallback(&tranceiverStruct, event);
		}
		''')
	}
		
	override generateEnable() {
		CodeFragment.EMPTY
	}
	
	private def getWidth(String register_width) {
		val regName = if(register_width.startsWith("array_")) {
			register_width.substring("array_register_".length);
		}
		else {
			register_width.substring("register_".length);
		}
		switch(regName) {
			case "int8": 1
			case "uint8": 1
			case "int16": 2
			case "uint16": 2
			case "int32": 4
			case "uint32": 4
		}
	}
	
	override generateSignalInstanceSetter(SignalInstance signalInstance, String resultName) {
		val busAddress = this.setup.getConfigurationItemValue("deviceAddress");
		val registerAddress = ModelUtils.getArgumentValue(signalInstance, 'address');
		
		val signalName = signalInstance.instanceOf.name;
		
		val isArray = signalName.startsWith("array_register")
		
		val preamble = if(isArray) {
			codeFragmentProvider.create('''
			if(«resultName»->length != «ModelUtils.getArgumentValue(signalInstance, 'length').code.noTerminator») {
				return EXCEPTION_INDEXOUTOFBOUNDSEXCEPTION;
			}
			''')
		} else {
			CodeFragment.EMPTY;
		}
		val data = if(isArray) {
			codeFragmentProvider.create('''(uint8_t*) «resultName»->data''');
		} else {
			codeFragmentProvider.create('''«resultName»''');
		}
		val dataLen = if(isArray) {
			codeFragmentProvider.create('''«resultName»->length / «signalName.getWidth»''')
		} else {
			codeFragmentProvider.create('''«signalName.getWidth»''');			
		}
		
		codeFragmentProvider.create('''
		«preamble»
		return I2CTransceiver_Write(&tranceiverStruct, «busAddress.code.noTerminator», «registerAddress.code.noTerminator», «data», «dataLen»);
		''')
		.addHeader("MitaExceptions.h", false)
		.addHeader("MitaGeneratedTypes.h", false)
	}
	
	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		val busAddress = this.setup.getConfigurationItemValue("deviceAddress");
		val registerAddress = ModelUtils.getArgumentValue(signalInstance, 'address');
		
		val signalName = signalInstance.instanceOf.name;
		
		val isArray = signalName.startsWith("array_register")
		
		val preamble = if(isArray) {
			codeFragmentProvider.create('''
			if(«resultName»->length != «ModelUtils.getArgumentValue(signalInstance, 'length').code.noTerminator») {
				return EXCEPTION_INDEXOUTOFBOUNDSEXCEPTION;
			}
			''')
		} else {
			CodeFragment.EMPTY;
		}
		val data = if(isArray) {
			codeFragmentProvider.create('''(uint8_t*) «resultName»->data''');
		} else {
			codeFragmentProvider.create('''«resultName»''');
		}
		val dataLen = if(isArray) {
			codeFragmentProvider.create('''«resultName»->length / «signalName.getWidth»''')
		} else {
			codeFragmentProvider.create('''«signalName.getWidth»''');			
		}
		
		codeFragmentProvider.create('''
		«preamble»
		return I2CTransceiver_Read(&tranceiverStruct, «busAddress.code.noTerminator», «registerAddress.code.noTerminator», «data», «dataLen»);
		''')
		.addHeader("MitaExceptions.h", false)
		.addHeader("MitaGeneratedTypes.h", false)
	}
}
