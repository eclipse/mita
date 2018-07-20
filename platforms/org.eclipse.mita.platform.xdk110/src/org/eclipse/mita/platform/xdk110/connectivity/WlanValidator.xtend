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

import java.util.regex.Pattern
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer.SumTypeRepr
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.xtext.validation.ValidationMessageAcceptor

class WlanValidator implements IResourceValidator {
	
	private static final Pattern IPV4_ADDR_PATTERN = Pattern.compile(
        "^(([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\.){3}([01]?\\d\\d?|2[0-4]\\d|25[0-5])$");
	
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		if(context instanceof SystemResourceSetup) {
			validateNetworkConfig(context, acceptor);
		}
	}
	
	protected def validateNetworkConfig(SystemResourceSetup setup, ValidationMessageAcceptor acceptor) {
		val ipConfigExpr = setup.getConfigurationItemValueOrDefault("ipConfiguration");
		val ipConfig = StaticValueInferrer.infer(ipConfigExpr, []);
		if(ipConfig instanceof SumTypeRepr) {
			val staticConfig = ipConfig.name == "Static"
		
			if(staticConfig) {
				val staticNetworkConfigItems = #['ip', 'subnetMask', 'gateway', 'dns'];
				for(item : staticNetworkConfigItems) {
					setup.validateConfigItemIsValidIpAddress(ipConfig, item, acceptor);				
				}
			}
		}
		else {
			acceptor.acceptError("Bad constructor", ipConfigExpr, null, 0, "VALIDATION_UNKNOWN_CONSTRUCTOR");
		}
	}
	
	protected def validateConfigItemIsValidIpAddress(SystemResourceSetup setup, SumTypeRepr staticConf, String item, ValidationMessageAcceptor acceptor) {
		val itemValue = staticConf.properties.get(item)
		val value = StaticValueInferrer.infer(itemValue, []);
		
		val isValidIpAddress = if(value instanceof String) {
			IPV4_ADDR_PATTERN.matcher(value).matches
		} else {
			false
		}
		
		if(!isValidIpAddress) {
			acceptor.acceptError(item + " must be a valid IPv4 address", itemValue, null, 0, "network_" + item + "_must_be_ipv4");
		}		
	}
}