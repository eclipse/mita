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
import java.util.HashMap
import java.util.Map
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.util.ExpressionUtils
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.inferrer.StaticValueInferrer

class LedGenerator extends AbstractSystemResourceGenerator {

	@Inject
	protected CodeFragmentProvider codeFragmentProvider

	public static def Map<SignalInstance, String> getSignalToColorAssignment(SystemResourceSetup context) {
		val result = new HashMap<SignalInstance, String>();
		
		context.signalInstances.forEach[vciv | 
			val color = #[vciv.initialization]
				.filter(ElementReferenceExpression)
				.map[x | ExpressionUtils.getArgumentValue(x.reference as Operation, x, "color") ]
				.map[ StaticValueInferrer.infer(it, []) ]
				.filter(Enumerator)
				.map[it.name]
				.head;
				
			result.put(vciv, color);
		]
		
		return result;
	}

	override generateSetup() {
		// find out which LEDs we need
		val colors = setup.signalToColorAssignment.values.toSet
		
		codeFragmentProvider.create('''
		Retcode_T ledSetupStatus = RETCODE_OK;
		ledSetupStatus = BSP_LED_Connect();
		if(ledSetupStatus != RETCODE_OK)
		{
			return ledSetupStatus;
		}
		«FOR color : colors»
		
		ledSetupStatus = BSP_LED_Enable((uint32_t) «color.handle»);
		if(ledSetupStatus != RETCODE_OK)
		{
			return ledSetupStatus;
		} 		
		«ENDFOR»
		''')
		.setPreamble('''
		«FOR color : colors»
		static bool «color.statusVariable» = false;
		«ENDFOR»
		''')
		.addHeader("BSP_BoardType.h", true, IncludePath.HIGH_PRIORITY)
		.addHeader("BCDS_BSP_LED.h", true)
		.addHeader("BCDS_Retcode.h", true)
	}
	
	private static def getStatusVariable(String color) {
		'''_ledStatus«color.toFirstUpper»'''
	}
	
	private static def getHandle(String color) {
		switch(color) {
			case 'Orange': 'BSP_XDK_LED_O'
			case 'Yellow': 'BSP_XDK_LED_Y'
			case 'Red': 'BSP_XDK_LED_R'
		}
	}
	
	override generateEnable() {
		CodeFragment.EMPTY
	}
	
	override generateSignalInstanceSetter(SignalInstance signalInstance, String valueVariableName) {
		val color = setup.signalToColorAssignment.get(signalInstance);
		
		codeFragmentProvider.create('''
		if(*«valueVariableName» == TRUE) {
			BSP_LED_Switch((uint32_t) «color.handle», (uint32_t) BSP_LED_COMMAND_ON);
		} else {
			BSP_LED_Switch((uint32_t) «color.handle», (uint32_t) BSP_LED_COMMAND_OFF);
		}
		«color.statusVariable» = *«valueVariableName»;
		''')
	}
	
	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		codeFragmentProvider.create('''
		*«resultName» = «setup.signalToColorAssignment.get(signalInstance).statusVariable»;
		''')
	}
}