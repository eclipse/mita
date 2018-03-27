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

import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import java.net.URI

class MqttGenerator extends AbstractSystemResourceGenerator {
	
	override generateSetup() {
		val brokerUri = new URI(configuration.getString("url"));
		var brokerPortRaw = brokerUri.port;
		val brokerPort = if(brokerPortRaw < 0) 1883 else brokerPortRaw;
		
		codeFragmentProvider.create('''
		retcode_t rc;
		
		rc = Mqtt_initialize();
		if(rc != RC_OK)
		{
			return EXCEPTION_EXCEPTION;
		}
		
		rc = Mqtt_initializeInternalSession(&mqttSession);
		if(rc != RC_OK)
		{
			return EXCEPTION_EXCEPTION;
		}
		
		mqttSession.MQTTVersion = 3;
		mqttSession.keepAliveInterval = «configuration.getInteger("keepAliveInterval")»;
		mqttSession.cleanSession = «configuration.getBoolean("cleanSession")»;
		mqttSession.will.haveWill = false;
		mqttSession.onMqttEvent = mqttEventHandler;
		
		StringDescr_T clientId;
		StringDescr_wrap(&clientId, MQTT_CLIENT_ID);
		mqttSession.clientID = clientId;
		''')
		.setPreamble('''
		/**
		 * The client identifier (here: clientID) is a identifier of each MQTT client
		 * connecting to a MQTT broker. It needs to be unique for the broker to
		 * know the state of the client.
		 *
		 * We define this client ID globally to ensure it's available in memory even
		 * after it was passed to the Serval stack in the setup method. 
		 */
		static const char* MQTT_CLIENT_ID = "«configuration.getString("clientId")»";
		
		static const char* MQTT_BROKER_HOST = "«brokerUri.host»";
		
		static const uint16_t MQTT_BROKER_PORT = «brokerPort»;
		
		MqttSession_T mqttSession;
		''')
		.addHeader("Serval_Mqtt.h", true, IncludePath.LOW_PRIORITY)
		.addHeader("stdint.h", true, IncludePath.HIGH_PRIORITY)
	}
	
	override generateEnable() {
		codeFragmentProvider.create('''
		retcode_t rc;
		Ip_Address_T brokerIpAddress;
		rc = PAL_getIpaddress((uint8_t *) MQTT_BROKER_HOST, &brokerIpAddress);
		if(rc != RC_OK)
		{
			return EXCEPTION_EXCEPTION;
		}
		
		/* Note:
		 *   Rather than filling the mqtt target structure ourselves, we could use the
		 *   SupportedUrl_fromString function. However, this would require use to "re-assemble"
		 *   a valid URL from the IP address, port and path.
		 */
		mqttSession.target.scheme = SERVAL_SCHEME_MQTT;
		mqttSession.target.address = brokerIpAddress;
		mqttSession.target.port = MQTT_BROKER_PORT;
		
		rc = Mqtt_connect(&mqttSession);
		if (rc != RC_OK) {
			printf("Could not connect to MQTT broker, error 0x%04x\n", rc);
			return EXCEPTION_EXCEPTION;
		}
		''')
		.addHeader('PAL_initialize_ih.h', true)
	}
	
	override generateAdditionalImplementation() {
		codeFragmentProvider.create('''
		retcode_t mqttEventHandler(MqttSession_T* session, MqttEvent_t event, const MqttEventData_t* eventData) {
			BCDS_UNUSED(eventData);
			
			switch(event) 
			{
				 case MQTT_CONNECTION_ESTABLISHED:
				 	// We're connected. Now we can subscribe() or publish()
				 	// At the moment we do not use this signal.
				 	break;
				 case MQTT_CONNECTION_ERROR:
				 	// Connection dropped. Try and reconnect.
				 	Mqtt_connect(session);
					break;
				default:
					break;
			}
			
			return RC_OK;
		}
		''')
		.setPreamble('''
		static retcode_t mqttEventHandler(MqttSession_T* session, MqttEvent_t event, const MqttEventData_t* eventData);
		''')
	}
	
	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		CodeFragment.EMPTY
	}
	
	override generateSignalInstanceSetter(SignalInstance signalInstance, String resultName) {
		val qosLevel = #[ "MQTT_QOS_AT_MOST_ONE", "MQTT_QOS_AT_LEAST_ONCE", "MQTT_QOS_EXACTLY_ONCE"	];
		val qosRaw = ModelUtils.getArgumentValue(signalInstance, 'qos');
		val qosRawValue = if(qosRaw === null) null else StaticValueInferrer.infer(qosRaw, [ ]);
		val qos = qosLevel.get((qosRawValue ?: 0) as Integer);
		
		return codeFragmentProvider.create('''
			static StringDescr_T topicDescription;
			static char *topic = "«StaticValueInferrer.infer(ModelUtils.getArgumentValue(signalInstance, 'name'), [ ])»";
			StringDescr_wrap(&topicDescription, topic);
			
			retcode_t rc = Mqtt_publish(&mqttSession, topicDescription, *«resultName», strlen(*«resultName»), «qos», false);
			if(rc != RC_OK) {
				return EXCEPTION_EXCEPTION;
			}
		''')
	}
	
}