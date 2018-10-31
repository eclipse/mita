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
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.program.ConfigurationItemValue
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.xtext.validation.ValidationMessageAcceptor

class AdcValidator implements IResourceValidator {
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		if(context instanceof SystemResourceSetup) {
			if(context.type?.name == "ADC") {
				val refVoltageConfig = getReferenceVoltageConfig(context);
				val usesExternalVoltage = context.signalInstances.fold(false, [uev, sigInst | validateSigInst(sigInst, refVoltageConfig, acceptor) || uev])
				if(!usesExternalVoltage && refVoltageConfig !== null) {
					acceptor.acceptWarning(
					'''Setting the external reference voltage has no effect unless you configure a signal with referenceVoltage set to an external reference voltage''',
					refVoltageConfig, null, 0, "");
				}
			}
		}
	}
	
	def validateSigInst(SignalInstance context, ConfigurationItemValue refVoltageConfig, ValidationMessageAcceptor acceptor) {

		val arg = ModelUtils.getArgumentValue(context, "referenceVoltage");
		val refVoltageEnum = StaticValueInferrer.infer(arg, []);
		if(refVoltageEnum instanceof Enumerator) {
			val refVoltage = refVoltageEnum.name;
			val isExternal = refVoltage.contains("Ext");
			if(isExternal && refVoltageConfig === null) {
				acceptor.acceptError(
				'''You need to set externalReferenceVoltage if you use referenceVoltage=«refVoltage»''',
				arg.eContainer, 
				null, 0, "");
			}
			return isExternal;
		}
		return false;
		
	}
	
	def ConfigurationItemValue getReferenceVoltageConfig(SystemResourceSetup setup) {
		return setup.configurationItemValues.findFirst[ configItem |
			configItem.item.name == "externalReferenceVoltage"
		];
	}
	
}