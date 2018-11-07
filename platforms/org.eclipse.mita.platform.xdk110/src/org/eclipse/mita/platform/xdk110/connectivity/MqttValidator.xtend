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

import java.net.MalformedURLException
import java.net.URI
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.xtext.validation.ValidationMessageAcceptor

class MqttValidator implements IResourceValidator {
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		if(context instanceof SystemResourceSetup) {
			validateUrl(context, acceptor);
			validateTopicQualityOfService(context, acceptor);
		}
	}
	
	def validateUrl(SystemResourceSetup setup, ValidationMessageAcceptor acceptor) {
		val urlConfigValue = setup.configurationItemValues.findFirst[ it.item.name == "url"];
		val url = setup.getConfigurationItemValue("url");
		if(url === null) return;
		
		val urlContent = StaticValueInferrer.infer(url, []);
		if(!(urlContent instanceof String)) {
			acceptor.acceptError("URL must be a string", urlConfigValue, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0, "url_must_be_string");
		}
		
		val urlContentString = urlContent as String;
		try {
			val parsedUrl = new URI(urlContentString);
			
			if(parsedUrl.scheme != 'mqtt') {
				acceptor.acceptError("Protocol must be mqtt (URL must start with mqtt://)", urlConfigValue, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0, "url_must_start_mqtt");
			}
			if(parsedUrl.host === null || parsedUrl.host.empty) {
				acceptor.acceptError("The URL must have a host (e.g. mqtt://thisismyhost.com)", urlConfigValue, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0, "url_must_have_host");
			}
			if(parsedUrl.path !== null && !parsedUrl.path.empty) {
				acceptor.acceptError('''The URL must not have a path (e.g. «parsedUrl.path»)''', urlConfigValue, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0, "url_mustnt_have_path");
			}			
		} catch(MalformedURLException e) {
			acceptor.acceptError("URL is malformed: " + e.message, urlConfigValue, ProgramPackage.Literals.CONFIGURATION_ITEM_VALUE__VALUE, 0, "url_is_malformed");
		}
	}
	
	def validateTopicQualityOfService(SystemResourceSetup setup, ValidationMessageAcceptor acceptor) {
		for(siginst : setup.signalInstances) {
			if(siginst.instanceOf.name == 'topic' || siginst.instanceOf.name == 'telemetry') {
				val qos = ModelUtils.getArgumentValue(siginst, "qos")
				if(qos !== null) {
					val qosValue = StaticValueInferrer.infer(qos, []);
					if(qosValue instanceof Integer) {
						if(qosValue < 0 || qosValue > 2) {
							acceptor.acceptError('''QOS level must be between 0 and 2''', qos.eContainer, ExpressionsPackage.Literals.ARGUMENT__VALUE, 0, "qos_level_oob");
						}
					}
				}
			}
		}
	}
	
	
}