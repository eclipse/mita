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

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.xtext.validation.ValidationMessageAcceptor
import org.yakindu.base.expressions.expressions.ElementReferenceExpression
import org.yakindu.base.types.Operation

class BleValidator implements IResourceValidator {
	
	

	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		if(context instanceof SystemResourceSetup) {
			validateUniqueUUIDs(program, context, acceptor);
			validateMacAddress(program, context, acceptor);
			
		}
	}
	
	private def validateUniqueUUIDs(Program program, SystemResourceSetup setup, ValidationMessageAcceptor acceptor) {
		val uuidGroups = setup.signalInstances.groupBy[x |
			val ref = x.initialization as ElementReferenceExpression;
			val arg = ModelUtils.getArgumentValue(ref.reference as Operation, ref, 'UUID');
			return StaticValueInferrer.infer(arg, [z | ]);
		];
		
		for(group : uuidGroups.entrySet) {
			if(group.value.length > 1) {
				acceptor.acceptError('UUID must be unique among characteristics', group.value.last, ProgramPackage.eINSTANCE.variableDeclaration_Initialization, 0, 'UUID_NOT_UNIQUE');
			}
		}
	}

	protected def validateMacAddress(Program program,SystemResourceSetup setup, ValidationMessageAcceptor acceptor) {
		val itemValue = setup.configurationItemValues.findFirst[ it.item.name == 'macAddress' ];
		if(itemValue !== null) {
			val value = StaticValueInferrer.infer(itemValue.value, []);
			if(value === null) {
				acceptor.acceptError('Unknown error in BLE validation', itemValue, null, 0, "");
			}
			if(value instanceof String) {
				val valid = BleGenerator.MAC_ADDRESS_PATTERN.matcher(value).matches
				if(!valid){
					acceptor.acceptError("Your MAC address is not in the correct format: " + value + "\nThe address should be of the format: FC:D6:BD:xx:xx:xx", itemValue, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0, "mac_address_wrong_format");								
				}					
			}
			else {
				acceptor.acceptError('Unknown error in BLE validation', itemValue, null, 0, "");
			}
		}
		else {
			// mac address is not configured, that's ok
		}
		
	}
}