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
import java.net.URL
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.Expression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator.LogLevel
import org.eclipse.mita.program.generator.TypeGenerator
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils

class RestClientGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	protected ITypeSystemInferrer typeInferrer
	
	@Inject
	protected extension GeneratorUtils
	
	@Inject
	protected TypeGenerator typeGenerator
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject(optional=true)
	protected IPlatformLoggingGenerator loggingGenerator

	@Inject
	protected ServalPALGenerator servalpalGenerator

	override generateAdditionalImplementation() {
		// TODO: infer buffer size based on signal instance use - at the moment generators have no way of doing that
		val httpBodyBufferSize = 512;
		val baseUrl = new URL(configuration.getString('endpointBase'));
		
		codeFragmentProvider.create('''
		/**
		 * @brief API responsible to pass the payload to the requested URL
		 *
		 * @param[in] omsh_ptr This data structure is used hold the buffer and information needed by the serializer.
		 *
		 */
		static retcode_t httpPayloadSerializer(OutMsgSerializationHandover_T* omsh_ptr)
		{
		    uint32_t offset = omsh_ptr->offset;
		    uint32_t bytesLeft = strlen(httpBodyBuffer) - offset;
		    uint32_t bytesToCopy = omsh_ptr->bufLen > bytesLeft ? bytesLeft : omsh_ptr->bufLen;
		
		    memcpy(omsh_ptr->buf_ptr, httpBodyBuffer + offset, bytesToCopy);
		    omsh_ptr->len = bytesToCopy;
		
		    if(bytesToCopy < bytesLeft) {
		    	return RC_MSG_FACTORY_INCOMPLETE;
		    } else {
		    	return RC_OK;
		    }
		}
		
		static retcode_t httpClientResponseCallback(HttpSession_T *httpSession, Msg_T *msg_ptr, retcode_t status) 
		{
			responseRetcode = status;
			responseStatusCode = HttpMsg_getStatusCode(msg_ptr);
			xSemaphoreGive(responseReceivedSemaphore);
			return RC_OK;
		}
		
		
		static retcode_t httpClientOnSentCallback(Callable_T *callfunc, retcode_t status) {
			«loggingGenerator.generateLogStatement(LogLevel.Debug, "Send HTTP request %s", codeFragmentProvider.create('''(status == RC_OK ? "OK" : "FAILED")'''))»
			return status;
		}
		''')
		.setPreamble('''
		static char httpBodyBuffer[«httpBodyBufferSize»];
		static SemaphoreHandle_t responseReceivedSemaphore;
		static Http_StatusCode_T responseStatusCode;
		static retcode_t responseRetcode;
		
		#define «setup.baseName.toUpperCase»_TIMEOUT (20000 / portTICK_PERIOD_MS)
		#define «setup.baseName.toUpperCase»_HOST    "«baseUrl.host»"
		
		static retcode_t httpPayloadSerializer(OutMsgSerializationHandover_T* omsh_ptr);
		static retcode_t httpClientResponseCallback(HttpSession_T *httpSession, Msg_T *msg_ptr, retcode_t status);
		static retcode_t httpClientOnSentCallback(Callable_T *callfunc, retcode_t status);
		''')
		.addHeader('Serval_Http.h', true)
		.addHeader('stdio.h', true)
		.addHeader('FreeRTOS.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('semphr.h', true)
	}
	
	override generateSignalInstanceSetter(SignalInstance signalInstance, String variableName) {
		val baseUrl = new URL(configuration.getString('endpointBase'));
		
		val httpMethod = ModelUtils.getArgumentValue(signalInstance, "writeMethod").httpMethod;
		val contentType = StaticValueInferrer.infer(ModelUtils.getArgumentValue(signalInstance, "contentType"), []);
		val url = '''«baseUrl.path»«StaticValueInferrer.infer(ModelUtils.getArgumentValue(signalInstance, 'endpoint'), [ ])»''';
		val port = if(baseUrl.port < 0) 80 else baseUrl.port;
		
		codeFragmentProvider.create('''
		size_t messageLength = strlen((const char*) *«variableName»);
		if(messageLength > sizeof(httpBodyBuffer))
		{
			return EXCEPTION_INDEXOUTOFBOUNDSEXCEPTION;
		}
		
		memcpy(httpBodyBuffer, *«variableName», strlen(*«variableName»));

		Retcode_T retcode = RETCODE_OK;
		Ip_Address_T destAddr;
		retcode = NetworkConfig_GetIpAddress((uint8_t*) «setup.baseName.toUpperCase»_HOST, &destAddr);
		if (retcode != RETCODE_OK)
		{
			return retcode;
		}

		retcode_t rc;
		Msg_T* msg_ptr;
		rc = HttpClient_initRequest(&destAddr, Ip_convertIntToPort(«port»), &msg_ptr);
		if (rc != RC_OK || msg_ptr == NULL)
		{
		    return rc;
		}
		
		HttpMsg_setReqMethod(msg_ptr, «httpMethod»);
		
		rc = HttpMsg_setHost(msg_ptr, «setup.baseName.toUpperCase»_HOST);
		if (rc != RC_OK)
		{
		    return rc;
		}
		
		const char* url_ptr = "«url»";
		rc = HttpMsg_setReqUrl(msg_ptr, url_ptr);
		if (rc != RC_OK)
		{
		    return rc;
		}
		
		HttpMsg_setContentType(msg_ptr, "«contentType»");
		rc = Msg_prependPartFactory(msg_ptr, &httpPayloadSerializer);
		if (rc != RC_OK) {
			return rc;
		}
		
		Callable_T sentCallable;
		(void) Callable_assign(&sentCallable, httpClientOnSentCallback);
		rc = HttpClient_pushRequest(msg_ptr, &sentCallable, &httpClientResponseCallback);
		if (rc != RC_OK)
		{
			return rc;
		}
		
		if(xSemaphoreTake(responseReceivedSemaphore, «setup.baseName.toUpperCase»_TIMEOUT) == pdTRUE)
		{
			if(responseRetcode != RC_OK) {
				return EXCEPTION_HTTPREQUESTNOTOKEXCEPTION;
			}
			else if(responseStatusCode == Http_StatusCode_OK)
			{
				return RC_OK;
			}
			else
			{
				«loggingGenerator.generateLogStatement(LogLevel.Warning, "HTTP response status code was %d", codeFragmentProvider.create('''responseStatusCode'''))»
				return EXCEPTION_HTTPREQUESTNOTOKEXCEPTION;
			}
		} 
		else
		{
			«loggingGenerator.generateLogStatement(LogLevel.Warning, "HTTP request timed out")»
			return EXCEPTION_TIMEOUTEXCEPTION;
		}
		''')
		.addHeader('BCDS_NetworkConfig.h', true, IncludePath.HIGH_PRIORITY)
	}
	
	protected def String getHttpMethod(Expression expression) {
		var result = 'Http_Method_Post';
		val enumerator = if(expression instanceof FeatureCall) {
			val feature = expression.feature;
			if(feature instanceof Enumerator) {
				feature
			}
		} else if(expression instanceof ElementReferenceExpression) {
			val ref = expression.reference;
			if(ref instanceof Enumerator) {
				ref
			}
		}
		if(enumerator !== null) {
			result = '''Http_Method_«enumerator.name.toLowerCase.toFirstUpper»'''
		}
		return result;
	}
	
	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		codeFragmentProvider.create('''
		return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
		''').addHeader('BCDS_Basics.h', true);
	}
	
	override generateSetup() {
		codeFragmentProvider.create('''
		Retcode_T retcode = RETCODE_OK;

		«servalpalGenerator.generateSetup()»

		responseReceivedSemaphore = xSemaphoreCreateBinary();
		''')
	}
	
	override generateEnable() {
		codeFragmentProvider.create('''
	    Retcode_T retcode = RETCODE_OK;

	    «servalpalGenerator.generateEnable()»

	    retcode = HttpClient_initialize();
	    if(retcode != RETCODE_OK) 
	    {
	    	return retcode;
	    }
		''')
		.addHeader("BCDS_Basics.h", true, IncludePath.HIGH_PRIORITY)
		.addHeader('Serval_HttpClient.h', true)
		.addHeader('Serval_Network.h', true)

	}
	
}