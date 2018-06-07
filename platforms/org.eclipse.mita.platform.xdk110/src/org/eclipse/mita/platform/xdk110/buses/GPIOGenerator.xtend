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
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import java.util.Map

class GPIOGenerator extends AbstractSystemResourceGenerator {
	
	
	val Map<String, String> modeTable = #{
		"NoPull" -> "BSP_EXTENSIONPORT_INPUT_NOPULL",
		"PullUp" -> "BSP_EXTENSIONPORT_INPUT_PULLUP",
		"PullDown" -> "BSP_EXTENSIONPORT_INPUT_PULLDOWN",
		"PullUpFilter" -> "BSP_EXTENSIONPORT_INPUTPULLFILTER"
	}
	
	val Map<String, Boolean> defaultValues = #{
		"NoPull" -> false,
		"PullUp" -> true,
		"PullDown" -> false,
		"PullUpFilter" -> true
	}	
		
	override generateSetup() {
		codeFragmentProvider.create('''
		Retcode_T exception = RETCODE_OK;
		
		BSP_Board_Delay(2000);
		
		exception = BSP_ExtensionPort_Connect();
		if(RETCODE_OK != exception) {
			printf("ExtensionPort_Connect failed");
			return exception;
		}
		
		BSP_Board_Delay(5);
		
		«FOR sigInst : setup.signalInstances»
		exception = BSP_ExtensionPort_ConnectGpio(«sigInst.pin»);
		if(RETCODE_OK != exception) {
			printf("connection of pin «sigInst.pinName» failed\n");
			return exception;
		}
		
		exception = BSP_ExtensionPort_SetGpioConfig(«sigInst.pin», BSP_EXTENSIONPORT_GPIO_PINMODE, «sigInst.pinMode», NULL);
		if(RETCODE_OK != exception) {
			printf("configuring pin mode for pin «sigInst.pinName» failed\n");
			return exception;
		}
		
		exception = BSP_ExtensionPort_SetGpioConfig(«sigInst.pin», BSP_EXTENSIONPORT_GPIO_PINVALUE, «sigInst.pinValue», NULL);
		if(RETCODE_OK != exception) {
			printf("configuring pin value for pin «sigInst.pinName» failed\n");
			return exception;
		}
		
		exception = BSP_ExtensionPort_EnableGpio(«sigInst.pin»);
		if(RETCODE_OK != exception) {
			printf("enabling pin «sigInst.pinName» failed\n");
			return exception;
		}
		
		«ENDFOR»
		
		return exception;
		''')
		.addHeader("BSP_ExtensionPort.h", true)
		.addHeader("BCDS_MCU_GPIO.h", true)
		.addHeader("BSP_BoardShared.h", true)
	}
	
	def CodeFragment getPinMode(SignalInstance sigInst) {
		val isOutput = sigInst.instanceOf.name.contains("Out");
		if(isOutput) {
			return codeFragmentProvider.create('''BSP_EXTENSIONPORT_PUSHPULL''');
		}
		val mode = StaticValueInferrer.infer(ModelUtils.getArgumentValue(sigInst, "mode"), []);
		if(mode instanceof Enumerator) {
			return codeFragmentProvider.create('''«modeTable.getOrDefault(mode.name, "ERROR_INVALID_ENUM_VALUE")»''');	
		}
		return CodeFragment.EMPTY;
	}
	
	def CodeFragment getPinValue(SignalInstance sigInst) {
		val isOutput = sigInst.instanceOf.name.contains("Out");
		if(isOutput) {
			val defaultVal = StaticValueInferrer.infer(ModelUtils.getArgumentValue(sigInst, "default"), []);
			if(defaultVal instanceof Boolean) {
				return codeFragmentProvider.create('''BSP_EXTENSIONPORT_GPIO_PIN_«if(defaultVal) "HIGH" else "LOW"»''');
			}
		}
		else {
			val mode = StaticValueInferrer.infer(ModelUtils.getArgumentValue(sigInst, "mode"), []);
			if(mode instanceof Enumerator) {
				val defaultVal = defaultValues.get(mode.name);
				if(defaultVal !== null) {
					return codeFragmentProvider.create('''BSP_EXTENSIONPORT_GPIO_PIN_«if(defaultVal) "HIGH" else "LOW"»''');
				}	
			}
		}
		return CodeFragment.EMPTY;
	}
	
	def CodeFragment getPinName(SignalInstance sigInst) {
		val enumValue = StaticValueInferrer.infer(ModelUtils.getArgumentValue(sigInst, "pin"), []);
		if(enumValue instanceof Enumerator) {
			return codeFragmentProvider.create('''«enumValue.name»''');	
		}
		return CodeFragment.EMPTY;
	}
	
	def CodeFragment getPin(SignalInstance sigInst) {
		return codeFragmentProvider.create('''BSP_EXTENSIONPORT_GPIO_«sigInst.pinName»''');
	}
	
	override generateEnable() {
		return CodeFragment.EMPTY;
	}
	
	override generateSignalInstanceGetter(SignalInstance sigInst, String resultName) {
		codeFragmentProvider.create('''return BSP_ExtensionPort_ReadGpio(«sigInst.pin», «resultName»);''')
	}
	
	override generateSignalInstanceSetter(SignalInstance sigInst, String valueVariableName) {
		codeFragmentProvider.create('''
		if(*«valueVariableName») {
			return BSP_ExtensionPort_SetGpio(«sigInst.pin»);
		} else {
			return BSP_ExtensionPort_ClearGpio(«sigInst.pin»);
		}
		''')
	}
	
}