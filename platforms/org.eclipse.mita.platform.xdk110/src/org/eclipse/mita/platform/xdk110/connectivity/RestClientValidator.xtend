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

import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.mita.program.Program
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.validation.ValidationMessageAcceptor
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import java.net.URL
import java.net.MalformedURLException
import com.google.common.base.Strings
import java.util.List

class RestClientValidator implements IResourceValidator  {
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		if(context instanceof SystemResourceSetup) {
			acceptor.acceptWarning("The HttpRestClient connectivity with security is experimental. Things might not work as expected.", context, ProgramPackage.Literals.SYSTEM_RESOURCE_SETUP__TYPE, 0, 'restclient_is_experimental');
			validateEndPointBase(context, acceptor);
			validateCustomHeader(context, acceptor);
		}
	}	
	
	protected def validateEndPointBase(SystemResourceSetup setup, ValidationMessageAcceptor acceptor) {
		val rawEndpointBaseItem = setup.configurationItemValues.findFirst[ it.item.name == 'endpointBase' ]
		val rawEndpointBase = rawEndpointBaseItem?.value;
		if(rawEndpointBase !== null) {
			val endpointValue = StaticValueInferrer.infer(rawEndpointBase, []);
			if(endpointValue instanceof String) {
				try {
					val endpointUrl = new URL(endpointValue);
					if(Strings.isNullOrEmpty(endpointUrl.protocol)) {
						acceptor.acceptError("Please include the protocol. Start with http://", rawEndpointBaseItem, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0, "no_protocol_in_url");
					} else if(endpointUrl.protocol != 'http') {
						acceptor.acceptError("Only http is supported as protocol", rawEndpointBaseItem, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0, "only_http_supported");
					} else if(Strings.isNullOrEmpty(endpointUrl.host)) {
						acceptor.acceptError("Host part of the URL is required", rawEndpointBaseItem, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0, "host_required");
					} else if(endpointValue.endsWith("/")) {
						acceptor.acceptWarning("Endpoint base should not end with a trailing slash. Remove the last /", rawEndpointBaseItem, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0, "no_trailing_slash");
					}
				} catch(MalformedURLException e) {
					acceptor.acceptError("URL is malformed. " + e.message?.toFirstUpper, rawEndpointBaseItem, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0, "malformed_endpoint_base");
				}
			}
		}		
	}
	
	protected def validateCustomHeader(SystemResourceSetup setup, ValidationMessageAcceptor acceptor) {
		val customHeaderItem = setup.configurationItemValues.findFirst[ it.item.name == 'customHeader' ]
		val customHeaderValues = customHeaderItem?.value;
		if(customHeaderValues !== null) {
			val customHeader = StaticValueInferrer.infer(customHeaderValues, []);
			if(customHeader instanceof List) {
				val headers = customHeader as List<String>;
				if(headers.size() > 2){
					acceptor.acceptError("Currently, maximum support for custom header size is only 2. ", customHeaderItem, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0, "malformed_custom_header");								
				}				
			}
			else
			{
				acceptor.acceptError("customHeader is not of type list. ", customHeaderItem, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0, "malformed_custom_header");
			}
		}
	}
	
}