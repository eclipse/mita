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
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.xtext.validation.ValidationMessageAcceptor

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import java.util.function.IntPredicate
import java.util.function.Predicate

class LoraValidator implements IResourceValidator {
	protected val rangeChecks = #{
		"EU" -> #{
			"bandFrequency" -> [long it | if(!(#[433, 868].contains(it))) {"one of 433, 868"}],
			"rx2Frequency" ->  [long it | if(!((433050 <= it && it <= 434790) || (863000 <= it && it <= 870000))) {"either between 433050 and 434790 or between 863000 and 870000"}],
			"rx2DataRate" ->   [long it | if(!(0 <= it && it <= 7)) {"between 0 and 7"}],
			"dataRate" ->      [long it | if(!(0 <= it && it <= 7)) {"between 0 and 7"}]
		}, 
		"US" -> #{
			"bandFrequency" -> [long it | if(!(it == 915)) {"exactly 915"}],
			"rx2Frequency" ->  [long it | if(!(923300 <= it && it <= 927500)) {"between 923300 and 927500"}],
			"rx2DataRate" ->   [long it | if(!(8 <= it && it <= 13)) {"between 8 and 13"}],
			"dataRate" ->      [long it | if(!(0 <= it && it <= 4)) {"between 0 and 4"}]
		}
	}
	
	protected val bandAndRx2Checks = #{
		"EU" -> [long fBand, long fRx2 | ((fBand / 100) as long) == ((fRx2 / 100000) as long)],
		"US" -> [a,b | true]
	}
	
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
			
			val region = StaticValueInferrer.infer(
				context.configurationItemValues.findFirst[ it.item.name == "region"], []
			).castOrNull(Enumerator)?.name;
			val checks = rangeChecks.get(region);
			if(checks !== null) {
				checks.entrySet.forEach[name_check | 
					val name = name_check.key;
					val check = name_check.value;
					
					val configItemValue = context.configurationItemValues.findFirst[it.item.name == name];
					val value = StaticValueInferrer.infer(configItemValue, []).castOrNull(Long);
					if(value !== null) {
						val msg = check.apply(value); 
						if(msg !== null) {
							acceptor.acceptError(value + " not in range for region " + region + ". Should be " + msg, configItemValue, null, 0, "");
						}
					}
				]
			}
			val bandRx2Check = bandAndRx2Checks.get(region);
			val fBandItem = context.configurationItemValues.findFirst[ it.item.name == "bandFrequency"]; 
			val fRx2Item = context.configurationItemValues.findFirst[ it.item.name == "rx2Frequency"];
			val fBand = StaticValueInferrer.infer(fBandItem, []).castOrNull(Long);
			val fRx2 = StaticValueInferrer.infer(fRx2Item, []).castOrNull(Long);
			
			if(bandRx2Check !== null && fBand !== null && fRx2 !== null && !bandRx2Check.apply(fBand, fRx2)) {
				val msg = "bandFrequency and rx2Frequency don't fit together";
				acceptor.acceptError(msg, fBandItem, null, 0, "");
				acceptor.acceptError(msg, fRx2Item, null, 0, "");
			} 
		}
	}
}

