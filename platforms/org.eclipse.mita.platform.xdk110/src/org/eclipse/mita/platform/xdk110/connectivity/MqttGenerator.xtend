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

import com.google.inject.Inject
import java.net.URI
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator.LogLevel
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.platform.xdk110.connectivity.ServalPalCommonGenerator

class MqttGenerator extends AbstractSystemResourceGenerator {
	
	@Inject(optional=true)
	protected IPlatformLoggingGenerator loggingGenerator
	
	override generateSetup() {
		val brokerUri = new URI(configuration.getString("url"));
		var brokerPortRaw = brokerUri.port;
		val brokerPort = if(brokerPortRaw < 0) 1883 else brokerPortRaw;

		codeFragmentProvider.create('''
		Retcode_T retcode = RETCODE_OK;

		retcode = ServalPal_Call()
		if (retcode != RETCODE_OK)
		{
			return retcode;
		}

		retcode = ServalPAL_Enable()

		if (retcode != RETCODE_OK)
		{
			return retcode;
		}

		mqttSubscribeHandle = xSemaphoreCreateBinary();
		if (NULL == mqttSubscribeHandle)
		{
			retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
		}
		if (RETCODE_OK == retcode)
		{
			mqttPublishHandle = xSemaphoreCreateBinary();
			if (NULL == mqttPublishHandle)
			{
				vSemaphoreDelete(mqttSubscribeHandle);
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
			}
		}
		if (RETCODE_OK == retcode)
		{
			mqttSendHandle = xSemaphoreCreateBinary();
			if (NULL == mqttSendHandle)
			{
				vSemaphoreDelete(mqttSubscribeHandle);
				vSemaphoreDelete(mqttPublishHandle);
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
			}
		}
		if (RETCODE_OK == retcode)
		{
			mqttConnectHandle = xSemaphoreCreateBinary();
			if (NULL == mqttConnectHandle)
			{
				vSemaphoreDelete(mqttSubscribeHandle);
				vSemaphoreDelete(mqttPublishHandle);
				vSemaphoreDelete(mqttSendHandle);
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
			}
		}
		return retcode;
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
		
		/**<  Macro for the non secure serval stack expected MQTT URL format */
		#define MQTT_URL_FORMAT_NON_SECURE          "mqtt://%s:%d"
		
		/**
		 * @brief   Structure to represent the MQTT connect features.
		 */
		typedef struct
		{
			const char * ClientId; /**< The client identifier which is a identifier of each MQTT client connecting to a MQTT broker. It needs to be unique for the broker to know the state of the client. */
			const char * BrokerURL; /**< The URL pointing to the MQTT broker */
			uint16_t BrokerPort; /**< The port number of the MQTT broker */
			bool CleanSession; /**< The clean session flag indicates to the broker whether the client wants to establish a clean session or a persistent session where all subscriptions and messages (QoS 1 & 2) are stored for the client. */
			uint32_t KeepAliveInterval; /**< The keep alive interval (in seconds) is the time the client commits to for when sending regular pings to the broker. The broker responds to the pings enabling both sides to determine if the other one is still alive and reachable */
		} ConnectivityMQTT_Connect_T;
				
		/**
		 * @brief   Structure to represent the MQTT publish features.
		 */
		typedef struct
		{
			const char * Topic; /**< The MQTT topic to which the messages are to be published */
			uint32_t QoS; /**< The MQTT Quality of Service level. If 0, the message is send in a fire and forget way and it will arrive at most once. If 1 Message reception is acknowledged by the other side, retransmission could occur. */
			const char * Payload; /**< Pointer to the payload to be published */
			uint32_t PayloadLength; /**< Length of the payload to be published */
		} ConnectivityMQTT_Publish_T;
				
		/**< Handle for MQTT subscribe operation  */
		static SemaphoreHandle_t mqttSubscribeHandle;
		/**< Handle for MQTT publish operation  */
		static SemaphoreHandle_t mqttPublishHandle;
		/**< Handle for MQTT send operation  */
		static SemaphoreHandle_t mqttSendHandle;
		/**< Handle for MQTT send operation  */
		static SemaphoreHandle_t mqttConnectHandle;
		/**< MQTT session instance */
		static MqttSession_T mqttSession;
		/**< MQTT connection status */
		static bool mqttIsConnected = false;
		/**< MQTT subscription status */
		static bool mqttIsSubscribed = false;
		/**< MQTT publish status */
		static bool mqttWasPublished = false;
		''')
		.addHeader("Serval_Mqtt.h", true, IncludePath.LOW_PRIORITY)
		.addHeader("stdint.h", true, IncludePath.HIGH_PRIORITY)
		.addHeader("XdkCommonInfo.h", true)
		.addHeader("BCDS_NetworkConfig.h", true)
		.addHeader("BCDS_ServalPal.h", true, IncludePath.HIGH_PRIORITY)
	}
	
	override generateEnable() {
		codeFragmentProvider.create('''
		Retcode_T retcode = RETCODE_OK;
		
		Ip_Address_T brokerIpAddress = 0UL;
		StringDescr_T clientID;
		char mqttBrokerURL[30] = { 0 };
		char serverIpStringBuffer[16] = { 0 };

		retcode_t mqttRetcode = RC_OK;
		mqttRetcode = Mqtt_initialize();
		if (RC_OK != mqttRetcode)
		{
			«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Enable : MQTT init failed: %x", codeFragmentProvider.create('''mqttRetcode'''))»
			retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_INIT_FAILED);
		}

		if (RETCODE_OK == retcode)
		{
			mqttRetcode = Mqtt_initializeInternalSession(&mqttSession);
			if (RC_OK != mqttRetcode)
			{
				«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Enable : MQTT init session failed: %x", codeFragmentProvider.create('''mqttRetcode'''))»
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_INIT_INTERNAL_SESSION_FAILED);
			}
		}

		if (RETCODE_OK == retcode)
		{
			retcode = NetworkConfig_GetIpAddress((uint8_t *) MQTT_BROKER_HOST, &brokerIpAddress);
			if(RETCODE_OK != retcode) {
				«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Enable : Failed to resolve host: %s", codeFragmentProvider.create('''MQTT_BROKER_HOST'''))»
			}
		}
		if (RETCODE_OK == retcode)
		{
			if (0 > Ip_convertAddrToString(&brokerIpAddress, serverIpStringBuffer))
			{
				«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Enable : Failed to convert IP")»
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_IPCONIG_FAIL);
			}
		}
		if (RETCODE_OK == retcode)
		{
			mqttSession.MQTTVersion = 3;
			mqttSession.keepAliveInterval = 60;
			mqttSession.cleanSession = false;
			mqttSession.will.haveWill = false;
			mqttSession.onMqttEvent = MqttEventHandler;

			StringDescr_wrap(&clientID, MQTT_CLIENT_ID);
			mqttSession.clientID = clientID;

			size_t neccessaryBytes = snprintf(mqttBrokerURL, sizeof(mqttBrokerURL), MQTT_URL_FORMAT_NON_SECURE, serverIpStringBuffer, MQTT_BROKER_PORT);
			if(neccessaryBytes > sizeof(mqttBrokerURL)) {
				«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Enable : Failed to convert IP")»
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
			}
		}
		if (RETCODE_OK == retcode)
		{
			mqttSession.target.scheme = SERVAL_SCHEME_MQTT;
			if (RC_OK == SupportedUrl_fromString((const char *) mqttBrokerURL, (uint16_t) strlen((const char *) mqttBrokerURL), &mqttSession.target))
			{
				mqttIsConnected = false;
				/* This is a dummy take. In case of any callback received
				 * after the previous timeout will be cleared here. */
				(void) xSemaphoreTake(mqttConnectHandle, 0UL);
				if (RC_OK != Mqtt_connect(&mqttSession))
				{
					«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Enable : Failed to connect MQTT")»
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_CONNECT_FAILED);
				}
			}
			else
			{
				«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Enable : Failed to parse IP/port: %s", codeFragmentProvider.create('''mqttBrokerURL'''))»
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_PARSING_ERROR);
			}
		}
		if (RETCODE_OK == retcode)
		{
			if (pdTRUE != xSemaphoreTake(mqttConnectHandle, pdMS_TO_TICKS(30000)))
			{
				«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Enable : Failed since Post CB was not received")»
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_CONNECT_CB_NOT_RECEIVED);
			}
			else
			{
				if (true != mqttIsConnected)
				{
					«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Enable : Failed to connect")»
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_CONNECT_STATUS_ERROR);
				}
			}
		}
		return retcode;
		''')

	}
	
	override generateAdditionalImplementation() {
		codeFragmentProvider.create('''
		/**
		 * @brief Callback function used by the stack to communicate events to the application.
		 * Each event will bring with it specialized data that will contain more information.
		 *
		 * @param[in] session
		 * MQTT session
		 *
		 * @param[in] event
		 * MQTT event
		 *
		 * @param[in] eventData
		 * MQTT data based on the event
		 *
		 */
		static retcode_t MqttEventHandler(MqttSession_T* session, MqttEvent_t event, const MqttEventData_t* eventData)
		{
			BCDS_UNUSED(session);
			Retcode_T retcode = RETCODE_OK;
			switch (event)
			{
			case MQTT_CONNECTION_ESTABLISHED:
				mqttIsConnected = true;
				if (pdTRUE != xSemaphoreGive(mqttConnectHandle))
				{
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
				break;
			case MQTT_CONNECTION_ERROR:
			case MQTT_CONNECT_SEND_FAILED:
			case MQTT_CONNECT_TIMEOUT:
				mqttIsConnected = false;
				if (pdTRUE != xSemaphoreGive(mqttConnectHandle))
				{
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
		
				break;
			case MQTT_CONNECTION_CLOSED:
				mqttIsConnected = false;
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_CONNECTION_CLOSED);
				break;
			case MQTT_SUBSCRIPTION_ACKNOWLEDGED:
				mqttIsSubscribed = true;
				if (pdTRUE != xSemaphoreGive(mqttSubscribeHandle))
				{
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
				break;
			case MQTT_SUBSCRIBE_SEND_FAILED:
			case MQTT_SUBSCRIBE_TIMEOUT:
				mqttIsSubscribed = false;
				if (pdTRUE != xSemaphoreGive(mqttSubscribeHandle))
				{
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
				break;
			case MQTT_SUBSCRIPTION_REMOVED:
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_SUBSCRIBE_REMOVED);
				break;
			case MQTT_INCOMING_PUBLISH:
				break;
			case MQTT_PUBLISHED_DATA:
				mqttWasPublished = true;
				if (pdTRUE != xSemaphoreGive(mqttPublishHandle))
				{
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
				break;
			case MQTT_PUBLISH_SEND_FAILED:
			case MQTT_PUBLISH_SEND_ACK_FAILED:
			case MQTT_PUBLISH_TIMEOUT:
				mqttWasPublished = false;
				if (pdTRUE != xSemaphoreGive(mqttPublishHandle))
				{
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
				break;
			default:
				printf("MqttEventHandler : Unhandled MQTT Event: %x\r\n", event);
				break;
			}
		
			if (RETCODE_OK != retcode)
			{
				Retcode_RaiseError(retcode);
			}
		
			return RC_OK;
		}
		''')
		.setPreamble('''
		static retcode_t MqttEventHandler(MqttSession_T* session, MqttEvent_t event, const MqttEventData_t* eventData);
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
			Retcode_T retcode = RETCODE_OK;
			
			static StringDescr_T publishTopicDescription;
			static char *topic = "«StaticValueInferrer.infer(ModelUtils.getArgumentValue(signalInstance, 'name'), [ ])»";
			StringDescr_wrap(&publishTopicDescription, topic);
			
			mqttWasPublished = false;
			/* This is a dummy take. In case of any callback received
			 * after the previous timeout will be cleared here. */
			(void) xSemaphoreTake(mqttPublishHandle, 0UL);
			if (RC_OK != Mqtt_publish(&mqttSession, publishTopicDescription, *value, strlen(*value), (uint8_t) MQTT_QOS_AT_MOST_ONE, false))
			{
			    retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_PUBLISH_FAILED);
			}
			if (RETCODE_OK == retcode)
			{
			    if (pdTRUE != xSemaphoreTake(mqttPublishHandle, pdMS_TO_TICKS(5000)))
			    {
			        retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_SUBSCRIBE_CB_NOT_RECEIVED);
			    }
			    else
			    {
			        if (true != mqttWasPublished)
			        {
			            retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_SUBSCRIBE_STATUS_ERROR);
			        }
			    }
			}
			return retcode;
		''')
	}
	
}