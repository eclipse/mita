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

package org.eclipse.mita.platform.xdk110.sensors

import org.eclipse.mita.platform.Sensor
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.validation.ValidationMessageAcceptor

class Max44009Validator implements IResourceValidator {
	
	public static final String NEEDS_MANUAL_MODE_MSG = 'Please set manual_mode to true for %s to take effect.';
	public static final String NEEDS_MANUAL_MODE_CODE = 'NEEDS_MANUAL_MODE_CODE';
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		val sensorSetup = ModelUtils.findSetupFor(program, Sensor, 'MAX44009');
		if(sensorSetup !== null) {
			// add warning of integration time or high brightness are configured with manual mode set to false
			val manualModeConfigItemValue = sensorSetup.configurationItemValues.findFirst[x | x.item.name == Max44009Generator.CONFIG_ITEM_MANUAL_MODE ]?.value;
			val manualMode = if(manualModeConfigItemValue === null) null else StaticValueInferrer.infer(manualModeConfigItemValue, [x | ]);
			if(manualMode === null || (manualMode instanceof Boolean && manualMode == false)) {
				acceptor.warnIfConfigItemPresent(sensorSetup, Max44009Generator.CONFIG_ITEM_HIGH_BRIGHTNESS);
				acceptor.warnIfConfigItemPresent(sensorSetup, Max44009Generator.CONFIG_ITEM_INTEGRATION_TIME);
			}
		}
	}
	
	private static def warnIfConfigItemPresent(ValidationMessageAcceptor acceptor, SystemResourceSetup sensorSetup, String configItemName) {
		val configItemIntegrationTime = sensorSetup.configurationItemValues.findFirst[x | x.item.name == configItemName];
		if(configItemIntegrationTime !== null) {
			acceptor.acceptWarning(
				String.format(NEEDS_MANUAL_MODE_MSG, configItemName), 
				configItemIntegrationTime, 
				ProgramPackage.eINSTANCE.configurationItemValue_Item, 
				-1,
				NEEDS_MANUAL_MODE_CODE
			); 
		}
	}
	
}