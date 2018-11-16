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

import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.base.expressions.ElementReferenceExpression

class AdcGenerator extends AbstractSystemResourceGenerator {
	
	override generateSetup() {
		val setupCode = codeFragmentProvider.create('''
			Retcode_T exception = RETCODE_OK;

			exception = AdcCentral_Init();
			if(exception != RETCODE_OK) return exception;

			AdcSampleSemaphore = xSemaphoreCreateBinary();
			if(AdcSampleSemaphore == NULL) {
				return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
			}
		''')
		.addHeader("FreeRTOS.h"  , true, 1000)
		.addHeader("semphr.h"    , true)
		.addHeader("BSP_Adc.h"   , true)
		.addHeader("Mcu_Adc.h"   , true)
		.addHeader("AdcCentral.h", true)
		
		setupCode.preamble = codeFragmentProvider.create('''
		uint16_t AdcResultBuffer = 0;
		SemaphoreHandle_t AdcSampleSemaphore = NULL;
		
		void adcCallback(ADC_T adc, uint16_t* buffer) {
			BCDS_UNUSED(adc);
			BCDS_UNUSED(buffer);
		
			BaseType_t higherPriorityTaskWoken = pdFALSE;
		
			if (pdTRUE == xSemaphoreGiveFromISR(AdcSampleSemaphore, &higherPriorityTaskWoken))
			{
				portYIELD_FROM_ISR(higherPriorityTaskWoken);
			}
			else
			{
				/* ignore... semaphore has already been given */
			}
		}
		
		«FOR channel: setup.signalInstances»
		AdcCentral_ConfigSingle_T «channel.configName» = {
			.AcqTime = «channel.sampleTime»,
			.Appcallback = adcCallback,
			.BufferPtr = &AdcResultBuffer,
			.Channel = «channel.channel»,
			.Reference = «channel.referenceVoltage»,
			.Resolution = «channel.resolution»
		};

		«ENDFOR»
		''')
		
		return setupCode;
	}
	
	def getConfigName(SignalInstance inst) {
		return '''«inst.name»_config''';
	}
	
	def getSampleTime(SignalInstance inst) {
		return '''ADC_ACQ_«inst.getArgumentEnum("sampleTime")?.name.toUpperCase»'''
	}
	def getChannel(SignalInstance inst) {
		return '''ADC_ENABLE_«inst.getArgumentEnum("channel")?.name.toUpperCase»'''
	}
	def getReferenceVoltage(SignalInstance inst) {
		return '''ADC_«inst.getArgumentEnum("referenceVoltage")?.name.replace("Ref", "REF")»'''
	}
	def getResolution(SignalInstance inst) {
		return '''ADC_«inst.getArgumentEnum("resolution")?.name.toUpperCase»'''
	}
	
	def int getResolutionBits(SignalInstance instance) {
		switch(instance.getArgumentEnum("resolution")?.name) {
			case "Resolution_12Bit": return 12
			case "Resolution_8Bit": return 8
			case "Resolution_6Bit": return 6
			case "Resolution_OVS": return 16
			default: return -1
		}
	}
	
	def getExternalReferenceVoltage() {
		val v = StaticValueInferrer.infer(setup.getConfigurationItemValue("externalReferenceVoltage"), [])
		if(v instanceof Integer) {
			return v.intValue
		}
		return -1;
	}
	
	def int getReferenceVoltageInMilliVolt(SignalInstance instance) {
		switch(instance.getArgumentEnum("referenceVoltage")?.name) {
			case "Ref_1V25": return 1250
			case "Ref_2V5":  return 2500
			case "Ref_VDD": return  2500
			case "Ref_5VDiff": return 5000
			case "Ref_ExtSingle": return getExternalReferenceVoltage() 
			case "Ref_ExtDiff": return getExternalReferenceVoltage() 
			case "Ref_2xVDD": return 5000
			default: return -1
		}
	}
	
	def getArgumentEnum(SignalInstance inst, String name) {
		val argValue = ModelUtils.getArgumentValue(inst, name);
		val value = StaticValueInferrer.infer(if(argValue instanceof ElementReferenceExpression) {
			argValue.reference
		}
		else {
			argValue;
		}, [])
		if(value instanceof Enumerator) {
			return value;
		}
	}
	
	override generateEnable() {
		return CodeFragment.EMPTY;
	}
	
	override generateSignalInstanceSetter(SignalInstance signalInstance, String valueVariableName) {
		return codeFragmentProvider.create('''
		return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
		''')
	}
	
	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		return codeFragmentProvider.create('''
		Retcode_T exception = NO_EXCEPTION;
		exception = AdcCentral_StartSingle(BSP_Adc_GetHandle(), &«signalInstance.configName»);
		if(exception != NO_EXCEPTION) return exception;
		if (pdTRUE != xSemaphoreTake(AdcSampleSemaphore, (TickType_t) pdMS_TO_TICKS(100)))
		{
			exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_TIMEOUT);
		}
		else
		{
			*«resultName» = AdcResultBuffer * «signalInstance.referenceVoltageInMilliVolt» / «1 << signalInstance.resolutionBits»;
		}
		''')
	}	
}