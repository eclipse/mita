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
		Retcode_T retcode = RETCODE_OK;
		MqttSubscribeHandle = xSemaphoreCreateBinary();
		if (NULL == MqttSubscribeHandle)
		{
			retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
		}
		if (RETCODE_OK == retcode)
		{
			MqttPublishHandle = xSemaphoreCreateBinary();
			if (NULL == MqttPublishHandle)
			{
				vSemaphoreDelete(MqttSubscribeHandle);
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
			}
		}
		if (RETCODE_OK == retcode)
		{
			MqttSendHandle = xSemaphoreCreateBinary();
			if (NULL == MqttSendHandle)
			{
				vSemaphoreDelete(MqttSubscribeHandle);
				vSemaphoreDelete(MqttPublishHandle);
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
			}
		}
		if (RETCODE_OK == retcode)
		{
			MqttConnectHandle = xSemaphoreCreateBinary();
			if (NULL == MqttConnectHandle)
			{
				vSemaphoreDelete(MqttSubscribeHandle);
				vSemaphoreDelete(MqttPublishHandle);
				vSemaphoreDelete(MqttSendHandle);
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
		struct ConnectivityMQTT_Connect_S
		{
			const char * ClientId; /**< The client identifier which is a identifier of each MQTT client connecting to a MQTT broker. It needs to be unique for the broker to know the state of the client. */
			const char * BrokerURL; /**< The URL pointing to the MQTT broker */
			uint16_t BrokerPort; /**< The port number of the MQTT broker */
			bool CleanSession; /**< The clean session flag indicates to the broker whether the client wants to establish a clean session or a persistent session where all subscriptions and messages (QoS 1 & 2) are stored for the client. */
			uint32_t KeepAliveInterval; /**< The keep alive interval (in seconds) is the time the client commits to for when sending regular pings to the broker. The broker responds to the pings enabling both sides to determine if the other one is still alive and reachable */
		};
		
		/**
		 * @brief   Typedef to represent the MQTT connect feature.
		 */
		typedef struct ConnectivityMQTT_Connect_S ConnectivityMQTT_Connect_T;
		
		/**
		 * @brief   Structure to represent the MQTT publish features.
		 */
		struct ConnectivityMQTT_Publish_S
		{
			const char * Topic; /**< The MQTT topic to which the messages are to be published */
			uint32_t QoS; /**< The MQTT Quality of Service level. If 0, the message is send in a fire and forget way and it will arrive at most once. If 1 Message reception is acknowledged by the other side, retransmission could occur. */
			const char * Payload; /**< Pointer to the payload to be published */
			uint32_t PayloadLength; /**< Length of the payload to be published */
		};
		
		/**
		 * @brief   Typedef to represent the MQTT publish feature.
		 */
		typedef struct ConnectivityMQTT_Publish_S ConnectivityMQTT_Publish_T;
		
		/**< Handle for MQTT subscribe operation  */
		static SemaphoreHandle_t MqttSubscribeHandle;
		/**< Handle for MQTT publish operation  */
		static SemaphoreHandle_t MqttPublishHandle;
		/**< Handle for MQTT send operation  */
		static SemaphoreHandle_t MqttSendHandle;
		/**< Handle for MQTT send operation  */
		static SemaphoreHandle_t MqttConnectHandle;
		/**< MQTT session instance */
		static MqttSession_T MqttSession;
		/**< MQTT connection status */
		static bool MqttConnectionStatus = false;
		/**< MQTT subscription status */
		static bool MqttSubscriptionStatus = false;
		/**< MQTT publish status */
		static bool MqttPublishStatus = false;
		
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
		''')
		.addHeader("Serval_Mqtt.h", true, IncludePath.LOW_PRIORITY)
		.addHeader("stdint.h", true, IncludePath.HIGH_PRIORITY)
		.addHeader("XdkCommonInfo.h", true)
		.addHeader("BCDS_NetworkConfig.h", true)
	}
	
	override generateEnable() {
		codeFragmentProvider.create('''
		Retcode_T retcode = RETCODE_OK;
		
		Ip_Address_T brokerIpAddress = 0UL;
		StringDescr_T clientID;
		char mqttBrokerURL[30] = { 0 };
		char serverIpStringBuffer[16] = { 0 };

		if (RC_OK != Mqtt_initialize())
		{
			retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_INIT_FAILED);
		}

		if (RETCODE_OK == retcode)
		{
			if (RC_OK != Mqtt_initializeInternalSession(&MqttSession))
			{
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_INIT_INTERNAL_SESSION_FAILED);
			}
		}

		if (RETCODE_OK == retcode)
		{
			retcode = NetworkConfig_GetIpAddress((uint8_t *) MQTT_BROKER_HOST, &brokerIpAddress);
		}
		if (RETCODE_OK == retcode)
		{
			if (0 > Ip_convertAddrToString(&brokerIpAddress, serverIpStringBuffer))
			{
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_IPCONIG_FAIL);
			}
		}
		if (RETCODE_OK == retcode)
		{
			MqttSession.MQTTVersion = 3;
			MqttSession.keepAliveInterval = 60;
			MqttSession.cleanSession = false;
			MqttSession.will.haveWill = false;
			MqttSession.onMqttEvent = MqttEventHandler;

			StringDescr_wrap(&clientID, MQTT_CLIENT_ID);
			MqttSession.clientID = clientID;

			sprintf(mqttBrokerURL, MQTT_URL_FORMAT_NON_SECURE, serverIpStringBuffer, MQTT_BROKER_PORT);
			MqttSession.target.scheme = SERVAL_SCHEME_MQTT;

			if (RC_OK == SupportedUrl_fromString((const char *) mqttBrokerURL, (uint16_t) strlen((const char *) mqttBrokerURL), &MqttSession.target))
			{
				MqttConnectionStatus = false;
				/* This is a dummy take. In case of any callback received
				 * after the previous timeout will be cleared here. */
				 (void) xSemaphoreTake(MqttConnectHandle, 0UL);
				if (RC_OK != Mqtt_connect(&MqttSession))
				{
					printf("MQTT_Enable : Failed to connect MQTT \r\n");
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_CONNECT_FAILED);
				}
			}
			else
			{
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_PARSING_ERROR);
			}
		}
		if (RETCODE_OK == retcode)
		{
			if (pdTRUE != xSemaphoreTake(MqttConnectHandle, pdMS_TO_TICKS(30000)))
			{
				printf("MQTT_Enable : Failed since Post CB was not received \r\n");
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_CONNECT_CB_NOT_RECEIVED);
			}
			else
			{
				if (true != MqttConnectionStatus)
				{
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_CONNECT_STATUS_ERROR);
				}
			}
		}
		return retcode;
		''')
		.addHeader('PAL_initialize_ih.h', true)
	}
	
	override generateAdditionalImplementation() {
		codeFragmentProvider.create('''
		static retcode_t MqttEventHandler(MqttSession_T* session, MqttEvent_t event, const MqttEventData_t* eventData)
		{
			BCDS_UNUSED(session);
			Retcode_T retcode = RETCODE_OK;
			printf("MqttEventHandler : Event - %d\r\n", (int) event);
			switch (event)
			{
			case MQTT_CONNECTION_ESTABLISHED:
				MqttConnectionStatus = true;
				if (pdTRUE != xSemaphoreGive(MqttConnectHandle))
				{
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
				break;
			case MQTT_CONNECTION_ERROR:
			case MQTT_CONNECT_SEND_FAILED:
			case MQTT_CONNECT_TIMEOUT:
				MqttConnectionStatus = false;
				if (pdTRUE != xSemaphoreGive(MqttConnectHandle))
				{
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
		
				break;
			case MQTT_CONNECTION_CLOSED:
				MqttConnectionStatus = false;
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_CONNECTION_CLOSED);
				break;
			case MQTT_SUBSCRIPTION_ACKNOWLEDGED:
				MqttSubscriptionStatus = true;
				if (pdTRUE != xSemaphoreGive(MqttSubscribeHandle))
				{
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
				break;
			case MQTT_SUBSCRIBE_SEND_FAILED:
			case MQTT_SUBSCRIBE_TIMEOUT:
				MqttSubscriptionStatus = false;
				if (pdTRUE != xSemaphoreGive(MqttSubscribeHandle))
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
				MqttPublishStatus = true;
				if (pdTRUE != xSemaphoreGive(MqttPublishHandle))
				{
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
				break;
			case MQTT_PUBLISH_SEND_FAILED:
			case MQTT_PUBLISH_SEND_ACK_FAILED:
			case MQTT_PUBLISH_TIMEOUT:
				MqttPublishStatus = false;
				if (pdTRUE != xSemaphoreGive(MqttPublishHandle))
				{
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
				break;
			default:
				printf("MqttEventHandler : Unhandled MQTT Event\r\n");
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
			
			MqttPublishStatus = false;
			/* This is a dummy take. In case of any callback received
			 * after the previous timeout will be cleared here. */
			(void) xSemaphoreTake(MqttPublishHandle, 0UL);
			if (RC_OK != Mqtt_publish(&MqttSession, publishTopicDescription, *value, strlen(*value), (uint8_t) MQTT_QOS_AT_MOST_ONE, false))
			{
			    retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_PUBLISH_FAILED);
			}
			if (RETCODE_OK == retcode)
			{
			    if (pdTRUE != xSemaphoreTake(MqttPublishHandle, pdMS_TO_TICKS(5000)))
			    {
			        retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_SUBSCRIBE_CB_NOT_RECEIVED);
			    }
			    else
			    {
			        if (true != MqttPublishStatus)
			        {
			            retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_SUBSCRIBE_STATUS_ERROR);
			        }
			    }
			}
			return retcode;
		''')
	}
	
}