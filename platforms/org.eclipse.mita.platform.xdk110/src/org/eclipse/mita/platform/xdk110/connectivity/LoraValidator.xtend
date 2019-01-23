/********************************************************************************
 * Copyright (c) 2019 Bosch Connected Devices and Solutions GmbH.
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

import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.xtext.validation.ValidationMessageAcceptor

class LoraValidator implements IResourceValidator {
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		if(context instanceof SystemResourceSetup) {
			val loraAppKey = context.configurationItemValues.findFirst[ it.item.name == "loraAppKey"];
			val loraAppEui = context.configurationItemValues.findFirst[ it.item.name == "loraAppEui"];
			val loraDeviceEui = context.configurationItemValues.findFirst[ it.item.name == "loraDeviceEui"];
			for(k_v: #[loraAppKey->16, loraAppEui->8, loraDeviceEui->8].filter[it.key !== null]) {
				val obj = StaticValueInferrer.infer(k_v.key.value, []);
				val length = k_v.value;
				if(obj instanceof List) {
					if(obj.size != length) {
						acceptor.acceptError(k_v.key.item.name + " needs exactly " + length + " bytes", k_v.key.value, null, 0, "");
					}
				}
				else {
					acceptor.acceptError("Configured value must be an array", k_v.key.value, null, 0, "");
				}
			}
		}
	}
	
}