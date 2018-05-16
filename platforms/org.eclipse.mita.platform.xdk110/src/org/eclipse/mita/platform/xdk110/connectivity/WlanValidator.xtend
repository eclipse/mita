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
import java.util.regex.Pattern
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.validation.ValidationMessageAcceptor
import java.util.Enumeration
import org.eclipse.xtext.xbase.scoping.featurecalls.StaticImplicitMethodsFeatureForTypeProvider.ExtensionClassNameProvider
import org.eclipse.xtext.serializer.sequencer.ITransientValueService.ValueTransient
import org.yakindu.base.types.Enumerator

class WlanValidator implements IResourceValidator {
	
	private static final Pattern IPV4_ADDR_PATTERN = Pattern.compile(
        "^(([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\.){3}([01]?\\d\\d?|2[0-4]\\d|25[0-5])$");
	
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		if(context instanceof SystemResourceSetup) {
			validateNetworkConfig(context, acceptor);
			validateConnectivityType(context, acceptor);
		}
	}
	
	protected def validateNetworkConfig(SystemResourceSetup setup, ValidationMessageAcceptor acceptor) {
		val useDhcpConfigItem = setup.configurationItemValues.findFirst[ it.item.name == "useDHCP" ];
		val useDhcp = if(useDhcpConfigItem === null) {
			true
		} else {
			StaticValueInferrer.infer(useDhcpConfigItem.value, []) as Boolean;
		}
		
		if(!useDhcp) {
			val staticNetworkConfigItems = #['staticIP', 'staticGW', 'staticDNS', 'staticMask'];
			for(item : staticNetworkConfigItems) {
				setup.validateConfigItemIsValidIpAddress(item, acceptor);				
			}
		}
	}
	
	protected def validateConfigItemIsValidIpAddress(SystemResourceSetup setup, String item, ValidationMessageAcceptor acceptor) {
		val itemValue = setup.configurationItemValues.findFirst[ it.item.name == item ];
		if(itemValue === null) {
			acceptor.acceptError("When not using DHCP, the " + item + " must be configured", setup, ProgramPackage.Literals.SYSTEM_RESOURCE_SETUP__TYPE, 0, "network_" + item + "_not_conf");								
		} else {
			val value = StaticValueInferrer.infer(itemValue.value, []);
			val isValidIpAddress = if(value instanceof String) {
				IPV4_ADDR_PATTERN.matcher(value).matches
			} else {
				false
			}
			
			if(!isValidIpAddress) {
				acceptor.acceptError(item + " must be a valid IPv4 address", itemValue, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0, "network_" + item + "_must_be_ipv4");
			}
		}
		
	}
	
	protected def validateConnectivityType(SystemResourceSetup setup, ValidationMessageAcceptor acceptor) {
		
		val connectivityConfigItem = setup.configurationItemValues.findFirst[x | x.item.name == 'connection'];
		val enterpriseOrPersonal = StaticValueInferrer.infer(connectivityConfigItem.value, []);
		if(enterpriseOrPersonal instanceof Enumerator) {
			if(enterpriseOrPersonal.name == "Enterprise") {
				val enterpriseHost = setup.configurationItemValues.findFirst[ it.item.name == "isHostPgmEnabled" ];
				if(enterpriseHost === null) {
					acceptor.acceptError("With enterprise set true, isHostPgmEnabled must be configured", connectivityConfigItem, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0, "network_IsHostPgmEnabled_not_conf");
				}
				val userName = setup.configurationItemValues.findFirst[ it.item.name == "userName" ];
				if(userName === null) {
					acceptor.acceptError("With enterprise set true, userName must be configured", connectivityConfigItem, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0, "network_userName_not_conf");
				}
			}	
		}
		else {
			acceptor.acceptError("We should never get here", setup, null, 0, null);
		}
	}
}