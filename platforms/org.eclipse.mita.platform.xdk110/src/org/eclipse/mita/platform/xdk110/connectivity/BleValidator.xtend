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

import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.validation.ValidationMessageAcceptor
import org.yakindu.base.expressions.expressions.ElementReferenceExpression
import org.eclipse.mita.program.model.ModelUtils
import org.yakindu.base.types.Operation
import org.yakindu.base.types.Enumerator

class BleValidator implements IResourceValidator {
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		if(context instanceof SystemResourceSetup) {
			validateUniqueUUIDs(program, context, acceptor);
			validateServiceType(context, acceptor);
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

    protected def validateServiceType(SystemResourceSetup setup, ValidationMessageAcceptor acceptor) {

		val ServiceConfigItem = setup.configurationItemValues.findFirst[x|x.item.name == 'Service'];
		val CustomService = StaticValueInferrer.infer(ServiceConfigItem.value, []);
		if (CustomService instanceof Enumerator) {
			if (CustomService.name == "BLE_USER_CUSTOM_SERVICE") {
				val customcharacteristic = setup.configurationItemValues.findFirst[it.item.name == "serviceUID"];
				if (customcharacteristic === null) {
					acceptor.acceptError("With custom service, serviceUID needs to be enabled",
						ServiceConfigItem, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0,
						"serviceUID_not_conf");
				}
			}
		} else {
			acceptor.acceptError("We should never get here", setup, null, 0, null);
		}
	}

}