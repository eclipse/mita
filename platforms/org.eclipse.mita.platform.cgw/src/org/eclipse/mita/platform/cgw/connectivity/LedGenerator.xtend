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
 
package org.eclipse.mita.platform.cgw.connectivity

import com.google.inject.Inject
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.GeneratorUtils

import static extension org.eclipse.mita.program.model.ModelUtils.getArgumentValue
import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import org.eclipse.mita.base.types.Singleton
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer.SumTypeRepr
import org.eclipse.mita.program.generator.CodeFragment

class LedGenerator extends AbstractSystemResourceGenerator {
	@Inject
	extension GeneratorUtils;
		
	override generateSetup() {
		return codeFragmentProvider.create('''
			Retcode_T exception = RETCODE_OK;
			
			exception = BSP_LED_Connect();
			
			return exception;
		''')
		.addHeader("BCDS_Retcode.h", true)
		.setPreamble('''
			«FOR led: setup.signalInstances»
			bool «led.baseName»_enabled = false;
			«ENDFOR»
		''')
	}
	
	override generateEnable() {
		return codeFragmentProvider.create('''
			Retcode_T exception = RETCODE_OK;
			
			exception = BSP_LED_Enable((uint32_t) COMMONGATEWAY_LED_ALL);
			
			return exception;
		''')
		.addHeader("BCDS_Retcode.h", true)
	}
	
	protected def String toId(Expression e) {
		val enumValue = StaticValueInferrer.infer(e, [])?.castOrNull(SumTypeRepr);
		if(enumValue === null) {
			return "UNKNOWN";
		}
		return switch(enumValue.name) {
			case "Red": "COMMONGATEWAY_LED_RED_ID"
			case "Green": "COMMONGATEWAY_LED_GREEN_ID"
			case "Blue": "COMMONGATEWAY_LED_BLUE_ID"
			default: "UNKNOWN"
		}
	}
	
	override generateSignalInstanceSetter(SignalInstance signalInstance, String valueVariableName) {
		return codeFragmentProvider.create('''
			enum CommonGateway_LED_Commands_E command;
			«signalInstance.baseName»_enabled = *«valueVariableName»;
			if(*«valueVariableName») {
				command = COMMONGATEWAY_LED_COMMAND_ON;
			}
			else {
				command = COMMONGATEWAY_LED_COMMAND_OFF;
			}
			return BSP_LED_Switch(«signalInstance.getArgumentValue("color").toId», command);
		''')
		.addHeader("BCDS_Retcode.h", true)
		.addHeader("BSP_CommonGateway.h", true)
	}
	
	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		return codeFragmentProvider.create('''
			*«resultName» = «signalInstance.baseName»_enabled;
		''')
	}
	
}