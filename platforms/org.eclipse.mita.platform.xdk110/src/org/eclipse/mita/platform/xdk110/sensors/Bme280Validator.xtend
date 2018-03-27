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
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.validation.ValidationMessageAcceptor

class Bme280Validator implements IResourceValidator {
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		val sensorSetup = ModelUtils.findSetupFor(program, Sensor, 'BME280');
		if(sensorSetup === null) return;
		
		val standbyItem = sensorSetup.configurationItemValues.findFirst[x | x.item.name == Bme280Generator.CONFIG_ITEM_STANDBY_TIME ];
		if(standbyItem !== null) {
			val specifiedTime = StaticValueInferrer.infer(standbyItem.value, [x| ]);
			if(specifiedTime instanceof Integer) {
				val producedTime = Bme280Generator.clipStandbyTime(specifiedTime)?.key;
				if(producedTime != specifiedTime) {
					acceptor.acceptInfo(String.format('Standby time will be rounded to the nearest configurable value of %s milliseconds', producedTime), standbyItem, ProgramPackage.eINSTANCE.configurationItemValue_Value, -1, 'BME280_STANDBYTIME_CFG_ROUND');
				}
			}
		}
	}
	
}