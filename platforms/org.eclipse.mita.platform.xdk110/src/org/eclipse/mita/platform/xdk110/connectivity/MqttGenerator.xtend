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
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator.LogLevel
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer.SumTypeRepr
import org.eclipse.mita.program.model.ModelUtils

class MqttGenerator extends AbstractSystemResourceGenerator {

	@Inject(optional=true)
	protected IPlatformLoggingGenerator loggingGenerator

	@Inject
	protected ServalPALGenerator servalpalGenerator

	@Inject
	protected extension StatementGenerator statementGenerator
	
	@Inject
	protected GeneratorUtils generatorUtils
	

	override generateSetup() {
		val brokerUri = new URI(configuration.getString("url"));
		var brokerPortRaw = brokerUri.port;
		val brokerPort = if(brokerPortRaw < 0) 1883 else brokerPortRaw;

		codeFragmentProvider.create('''
		Retcode_T exception = RETCODE_OK;

		«servalpalGenerator.generateSetup()»

		mqttSubscribeHandle = xSemaphoreCreateBinary();
		if (NULL == mqttSubscribeHandle)
		{
			exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
		}
		
		«generatorUtils.generateExceptionHandler(setup, "exception")»
		
			mqttPublishHandle = xSemaphoreCreateBinary();
			if (NULL == mqttPublishHandle)
			{
				vSemaphoreDelete(mqttSubscribeHandle);
				exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
			}
		
		«generatorUtils.generateExceptionHandler(setup, "exception")»
		
		mqttSendHandle = xSemaphoreCreateBinary();
		if (NULL == mqttSendHandle)
		{
			vSemaphoreDelete(mqttSubscribeHandle);
			vSemaphoreDelete(mqttPublishHandle);
			exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
		}
		
		«generatorUtils.generateExceptionHandler(setup, "exception")»
		
		mqttConnectHandle = xSemaphoreCreateBinary();
		if (NULL == mqttConnectHandle)
		{
			vSemaphoreDelete(mqttSubscribeHandle);
			vSemaphoreDelete(mqttPublishHandle);
			vSemaphoreDelete(mqttSendHandle);
			exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
		}
		
		return exception;
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
	}

	override generateEnable() {
		val auth = StaticValueInferrer.infer(configuration.getExpression("authentication"), []);
		val result = codeFragmentProvider.create('''
		Retcode_T exception = RETCODE_OK;

		Ip_Address_T brokerIpAddress = 0UL;
		StringDescr_T clientID;
		char mqttBrokerURL[30] = { 0 };
		char serverIpStringBuffer[16] = { 0 };

		«servalpalGenerator.generateEnable()»

		retcode_t mqttRetcode = RC_OK;
		mqttRetcode = Mqtt_initialize();
		if (RC_OK != mqttRetcode)
		{
			«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Enable : MQTT init failed: %x", codeFragmentProvider.create('''mqttRetcode'''))»
			exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_INIT_FAILED);
		}

		«generatorUtils.generateExceptionHandler(setup, "exception")»
		
		mqttRetcode = Mqtt_initializeInternalSession(&mqttSession);
		if (RC_OK != mqttRetcode)
		{
			«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Enable : MQTT init session failed: %x", codeFragmentProvider.create('''mqttRetcode'''))»
			exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_INIT_INTERNAL_SESSION_FAILED);
		}

		«generatorUtils.generateExceptionHandler(setup, "exception")»
		
		exception = NetworkConfig_GetIpAddress((uint8_t *) MQTT_BROKER_HOST, &brokerIpAddress);
		if(RETCODE_OK != exception) {
			«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Enable : Failed to resolve host: %s", codeFragmentProvider.create('''MQTT_BROKER_HOST'''))»
			return exception;
		}
		
		«generatorUtils.generateExceptionHandler(setup, "exception")»
		
		if (0 > Ip_convertAddrToString(&brokerIpAddress, serverIpStringBuffer))
		{
			«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Enable : Failed to convert IP")»
			exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_IPCONIG_FAIL);
		}

		«generatorUtils.generateExceptionHandler(setup, "exception")»

		mqttSession.MQTTVersion = 3;
		mqttSession.keepAliveInterval = 60;
		mqttSession.cleanSession = false;
		mqttSession.will.haveWill = false;
		mqttSession.onMqttEvent = MqttEventHandler;
		«IF auth instanceof SumTypeRepr»
			«IF auth.isLogin()»
				mqttSession.username = username;
				mqttSession.password = password;
			«ENDIF»
		«ENDIF»

		StringDescr_wrap(&clientID, MQTT_CLIENT_ID);
		mqttSession.clientID = clientID;

		size_t neccessaryBytes = snprintf(mqttBrokerURL, sizeof(mqttBrokerURL), MQTT_URL_FORMAT_NON_SECURE, serverIpStringBuffer, MQTT_BROKER_PORT);
		if(neccessaryBytes > sizeof(mqttBrokerURL)) {
			«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Enable : Failed to convert IP")»
			exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
		}
		
		«generatorUtils.generateExceptionHandler(setup, "exception")»
		
		mqttSession.target.scheme = SERVAL_SCHEME_MQTT;
		if (RC_OK == SupportedUrl_fromString((const char *) mqttBrokerURL, (uint16_t) strlen((const char *) mqttBrokerURL), &mqttSession.target))
		{
			exception = connectToBackend();
		}
		else
		{
			«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Enable : Failed to parse IP/port: %s", codeFragmentProvider.create('''mqttBrokerURL'''))»
			exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_PARSING_ERROR);
		}
		
		return exception;
		''');
		if(auth instanceof SumTypeRepr) {
			if(auth.isLogin()) {
				val username = auth.properties.get("username")?.code;
				val password = auth.properties.get("password")?.code;
				result.setPreamble('''

                StringDescr_T username;
                const char* usernameBuf = «username»;
                StringDescr_wrap(&username, usernameBuf);

                StringDescr_T password;
                const char* passwordBuf = «password»;
                StringDescr_wrap(&password, passwordBuf);
				''').addHeader("Serval_StringDescr.h", true);
			}
		}

		return result;

	}

	protected def isLogin(SumTypeRepr repr) {
		return repr.name == "Login"
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
			BCDS_UNUSED(eventData);
			Retcode_T exception = RETCODE_OK;
			switch (event)
			{
			case MQTT_CONNECTION_ESTABLISHED:
				mqttIsConnected = true;
				if (pdTRUE != xSemaphoreGive(mqttConnectHandle))
				{
					exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
				break;
			case MQTT_CONNECTION_ERROR:
			case MQTT_CONNECT_SEND_FAILED:
			case MQTT_CONNECT_TIMEOUT:
				mqttIsConnected = false;
				if (pdTRUE != xSemaphoreGive(mqttConnectHandle))
				{
					exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}

				break;
			case MQTT_CONNECTION_CLOSED:
				mqttIsConnected = false;
				«loggingGenerator.generateLogStatement(LogLevel.Warning, "MQTT_Event : Disconnected. Will try to reconnect on next send.")»
				break;
			case MQTT_SUBSCRIPTION_ACKNOWLEDGED:
				mqttIsSubscribed = true;
				if (pdTRUE != xSemaphoreGive(mqttSubscribeHandle))
				{
					exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
				break;
			case MQTT_SUBSCRIBE_SEND_FAILED:
			case MQTT_SUBSCRIBE_TIMEOUT:
				mqttIsSubscribed = false;
				if (pdTRUE != xSemaphoreGive(mqttSubscribeHandle))
				{
					exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
				break;
			case MQTT_SUBSCRIPTION_REMOVED:
				exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_SUBSCRIBE_REMOVED);
				break;
			case MQTT_INCOMING_PUBLISH:
				break;
			case MQTT_PUBLISHED_DATA:
				mqttWasPublished = true;
				if (pdTRUE != xSemaphoreGive(mqttPublishHandle))
				{
					exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
				break;
			case MQTT_PUBLISH_SEND_FAILED:
			case MQTT_PUBLISH_SEND_ACK_FAILED:
			case MQTT_PUBLISH_TIMEOUT:
				mqttWasPublished = false;
				if (pdTRUE != xSemaphoreGive(mqttPublishHandle))
				{
					exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
				break;
			default:
				«loggingGenerator.generateLogStatement(LogLevel.Info, "MqttEventHandler : Unhandled MQTT Event: %x", codeFragmentProvider.create('''event'''))»
				break;
			}

			if (RETCODE_OK != exception)
			{
				Retcode_RaiseError(exception);
			}

			return RC_OK;
		}
		
		/**
		 * Connects to a configured backend.
		 */
		Retcode_T connectToBackend(void) {
			/* This is a dummy take. In case of any callback received
			 * after the previous timeout will be cleared here. */
			(void) xSemaphoreTake(mqttConnectHandle, 0UL);
			if(RC_OK != Mqtt_connect(&mqttSession)) {
				«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Connect : Failed to connect MQTT")»
				return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_CONNECT_FAILED);
			}
			if (pdTRUE != xSemaphoreTake(mqttConnectHandle, pdMS_TO_TICKS(30000)))
			{
				«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Connect : Failed since Post CB was not received")»
				return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_CONNECT_CB_NOT_RECEIVED);
			}
			if (!mqttIsConnected)
			{
				«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Connect : Failed to connect")»
				return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_CONNECT_STATUS_ERROR);
			}
			return RETCODE_OK;
		}
		''')
		.setPreamble('''
		static retcode_t MqttEventHandler(MqttSession_T* session, MqttEvent_t event, const MqttEventData_t* eventData);
		static Retcode_T connectToBackend(void);
		''')
	}

	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		CodeFragment.EMPTY
	}

	override generateSignalInstanceSetter(SignalInstance signalInstance, String resultName) {
		val qosLevel = #[ "MQTT_QOS_AT_MOST_ONE", "MQTT_QOS_AT_LEAST_ONCE", "MQTT_QOS_EXACTLY_ONCE"	];

		val qosRaw = ModelUtils.getArgumentValue(signalInstance, 'qos');
		val qosRawValue = if(qosRaw === null) null else StaticValueInferrer.infer(qosRaw, [ ]);
		val qos = qosLevel.get(((qosRawValue ?: 0) as Long).longValue as int);
		
		return codeFragmentProvider.create('''
			Retcode_T exception = RETCODE_OK;
			
			if(!mqttIsConnected) {
				«loggingGenerator.generateLogStatement(LogLevel.Info, "MQTT_Write : Reconnecting...")»
				exception = connectToBackend();
				if(mqttIsConnected) {
					«loggingGenerator.generateLogStatement(LogLevel.Info, "MQTT_Write : Connected.")»
				}
				else {
					«loggingGenerator.generateLogStatement(LogLevel.Error, "MQTT_Write : Connection failed!")»
				}
			}
			«generatorUtils.generateExceptionHandler(signalInstance, "exception")»

			static StringDescr_T publishTopicDescription;
			static char *topic = "«getTopicName(signalInstance)»";
			StringDescr_wrap(&publishTopicDescription, topic);

			mqttWasPublished = false;
			/* This is a dummy take. In case of any callback received
			 * after the previous timeout will be cleared here. */
			(void) xSemaphoreTake(mqttPublishHandle, 0UL);
			if (RC_OK != Mqtt_publish(&mqttSession, publishTopicDescription, *value, strlen(*value), (uint8_t) «qos», false))
			{
			    exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_PUBLISH_FAILED);
			}
			
			«generatorUtils.generateExceptionHandler(signalInstance, "exception")»
			
			if (pdTRUE != xSemaphoreTake(mqttPublishHandle, pdMS_TO_TICKS(5000)))
			{
				exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_SUBSCRIBE_CB_NOT_RECEIVED);
			}
			else
			{
				if (true != mqttWasPublished)
				{
					exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_MQTT_SUBSCRIBE_STATUS_ERROR);
				}
			}
			
			return exception;
		''')
	}

	protected def int getQosLevel(SignalInstance instance) {
		val qosRaw = ModelUtils.getArgumentValue(instance, 'qos');
		val qosRawValue = if(qosRaw === null) null else StaticValueInferrer.infer(qosRaw, [ ]) as Integer;
		return Math.min(Math.max(qosRawValue ?: 0, 0), 3);
	}

	protected def String getTopicName(SignalInstance instance) {
		return StaticValueInferrer.infer(ModelUtils.getArgumentValue(instance, 'name'), [ ]) as String;
	}

}