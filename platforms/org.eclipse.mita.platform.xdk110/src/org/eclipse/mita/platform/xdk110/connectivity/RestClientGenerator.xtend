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
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.TypeGenerator
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import com.google.inject.Inject
import java.net.URL
import org.yakindu.base.expressions.expressions.ElementReferenceExpression
import org.yakindu.base.expressions.expressions.Expression
import org.yakindu.base.expressions.expressions.FeatureCall
import org.yakindu.base.types.Enumerator
import org.yakindu.base.types.inferrer.ITypeSystemInferrer

class RestClientGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	protected ITypeSystemInferrer typeInferrer
	
	@Inject
	protected extension GeneratorUtils
	
	@Inject
	protected TypeGenerator typeGenerator

	override generateSetup() {
		codeFragmentProvider.create('''
		static CmdProcessor_T * AppCmdProcessor;

		Retcode_T retcode = ServalPAL_Setup(AppCmdProcessor);
		printf("ServalPAL_Setup1");
		if (RETCODE_OK != retcode)
		{		
			printf("ServalPAL_Setup fail");
		}
		else
		{
			printf("ServalPAL_Setup1 success");
		}
		#if HTTP_SECURE_ENABLE
		if (RETCODE_OK == retcode)
		{
		    retcode = SNTP_Setup(&SNTPSetupInfo);
		}
		#endif /* HTTP_SECURE_ENABLE */

		if (RETCODE_OK == retcode)
		{
		    retcode = HTTPRestClient_Setup(&HTTPRestClientSetupInfo);
		}
		return retcode;
		''')
		.addHeader("BCDS_Basics.h", true, IncludePath.HIGH_PRIORITY)
		.addHeader("BCDS_Retcode.h", true, IncludePath.HIGH_PRIORITY)
		.addHeader('XDK_ServalPAL.h', true)
		.addHeader('XDK_SNTP.h', true)
		.addHeader('XDK_HTTPRestClient.h', true)
		.addHeader('task.h', true)
		.addHeader('BCDS_BSP.h', true)
		.addHeader('task.h', true)
		.addHeader('FreeRTOS.h', true)
	}

	override generateEnable() {
		codeFragmentProvider.create('''
		static CmdProcessor_T CommandProcessorHandle;

		Retcode_T retcode = CmdProcessor_Initialize(&CommandProcessorHandle, "Serval PAL", TASK_PRIORITY_SERVALPAL_CMD_PROC, TASK_STACK_SIZE_SERVALPAL_CMD_PROC, TASK_QUEUE_LEN_SERVALPAL_CMD_PROC);
		if (RETCODE_OK == retcode)
		{
			retcode = ServalPAL_Setup(&CommandProcessorHandle);
		}
		#if HTTP_SECURE_ENABLE
		if (RETCODE_OK == retcode)
		{
		    retcode = SNTP_Setup(&SNTPSetupInfo);
		}
		#endif /* HTTP_SECURE_ENABLE */

		if (RETCODE_OK == retcode)
		{
		    retcode = HTTPRestClient_Setup(&HTTPRestClientSetupInfo);
		}
		// @todo: remove block later
		if (RETCODE_OK == retcode)
		{
			printf("Setup block successfull\n");
		}
		// @todo: remove later

		retcode = ServalPAL_Enable();

		#if HTTP_SECURE_ENABLE
		if (RETCODE_OK == retcode)
		{
		    retcode = SNTP_Enable();
			if (RETCODE_OK != retcode)
			{		
				printf("SNTP_Enable");
			}
		}
		#endif /*HTTP_SECURE_ENABLE*/

		if (RETCODE_OK == retcode)
		{
		    retcode = HTTPRestClient_Enable();
		}
		
		// @todo: remove block later
		if (RETCODE_OK == retcode)
		{
			printf("Enable block successfull\n");
		}
		// @todo: remove later
		return retcode;
		''')
		.setPreamble('''
		/**< Main command processor task priority */
		#define TASK_PRIORITY_SERVALPAL_CMD_PROC                (UINT32_C(3))
		/**< Main command processor task stack size */
		#define TASK_STACK_SIZE_SERVALPAL_CMD_PROC          (UINT32_C(700))
		/**< Main command processor task queue length */
		#define TASK_QUEUE_LEN_SERVALPAL_CMD_PROC               (UINT32_C(10))		
		''')
	}

	override generateSignalInstanceSetter(SignalInstance signalInstance, String variableName) {
		val baseUrl = new URL(configuration.getString("endpointBase"));
		val port = if(baseUrl.port < 0) 80 else baseUrl.port;
		val customHeader = configuration.getString("customHeader"); // @todo: check how to extract the array values
		val endpoint = StaticValueInferrer.infer(ModelUtils.getArgumentValue(signalInstance, "endpoint"), [ ]);
		val httpWriteMethod = ModelUtils.getArgumentValue(signalInstance, "writeMethod").httpMethod;
		val httpReadMethod = ModelUtils.getArgumentValue(signalInstance, "readMethod").httpMethod;
		val contentType = StaticValueInferrer.infer(ModelUtils.getArgumentValue(signalInstance, "contentType"), []); // @todo: where is it used?
		
		codeFragmentProvider.create('''
		Retcode_T rc = RETCODE_FAILURE;
		
		/**< HTTP rest client configuration parameters */
		static HTTPRestClient_Config_T HTTPRestClientConfigInfo =
		{
		       .IsSecure = HTTP_SECURE_ENABLE,
		       .DestinationServerUrl = "«baseUrl.host»", // @todo: replace with user parameter url or baseUrl
		       .DestinationServerPort = «port»,
		       .RequestMaxDownloadSize = REQUEST_MAX_DOWNLOAD_SIZE,
		};
		
		/**< HTTP rest client POST parameters */
		static HTTPRestClient_Post_T HTTPRestClientPostInfo =
		{
				.Payload = POST_REQUEST_BODY,
				.PayloadLength = (sizeof(POST_REQUEST_BODY) - 1U),
		        .Url = "/post",//getHttpMethod("«httpWriteMethod»"),
		        .RequestCustomHeader0 = POST_REQUEST_CUSTOM_HEADER_0,
		        .RequestCustomHeader1 = POST_REQUEST_CUSTOM_HEADER_1,
		};
		
		/**< HTTP rest client GET parameters */
		static HTTPRestClient_Get_T HTTPRestClientGetInfo =
		{
		        .Url = "/get",//getHttpMethod("«httpReadMethod»"),
		        .GetCB = NULL,
		};

		#if HTTP_SECURE_ENABLE
		uint64_t sntpTimeStampFromServer = 0UL;
		
		/* We Synchronize the node with the SNTP server for time-stamp.
		 * Since there is no point in doing a HTTPS communication without a valid time */
		do
		{
		    rc = SNTP_GetTimeFromServer(&sntpTimeStampFromServer, APP_RESPONSE_FROM_SNTP_SERVER_TIMEOUT);
		    if((RETCODE_OK != rc) ||(0UL == sntpTimeStampFromServer))
		    {
		        printf("AppControllerFire : SNTP server time was not synchronized. Retrying...\r\n");
		    }
		}while (0UL == sntpTimeStampFromServer);
		
		BCDS_UNUSED(sntpTimeStampFromServer); /* Copy of sntpTimeStampFromServer will be used be HTTPS for TLS handshake */
		#endif /* HTTP_SECURE_ENABLE */

		rc = HTTPRestClient_Post(&HTTPRestClientConfigInfo, &HTTPRestClientPostInfo, APP_RESPONSE_FROM_HTTP_SERVER_POST_TIMEOUT);
		if (RETCODE_OK == rc)
		{
		    /* Wait for INTER_REQUEST_INTERVAL */
		    vTaskDelay(pdMS_TO_TICKS(INTER_REQUEST_INTERVAL));
		    /* Do a HTTP rest client GET */
		    rc = HTTPRestClient_Get(&HTTPRestClientConfigInfo, &HTTPRestClientGetInfo, APP_RESPONSE_FROM_HTTP_SERVER_GET_TIMEOUT);
		}

		if (RETCODE_OK != rc)
		{
			return rc;
		}
		''')
		.setPreamble('''
		#define HTTP_SECURE_ENABLE «configuration.getBoolean("isSecurityEnabled")»
		#define APP_RESPONSE_FROM_HTTP_SERVER_POST_TIMEOUT  UINT32_C(10000)
		/**< Timeout for completion of HTTP rest client GET */
		#define APP_RESPONSE_FROM_HTTP_SERVER_GET_TIMEOUT       UINT32_C(10000)
		/**
		 * The maximum amount of data we download in a single request (in bytes). This number is
		 * limited by the platform abstraction layer implementation that ships with the
		 * XDK. The maximum value that will work here is 512 bytes.
		 */
		#define REQUEST_MAX_DOWNLOAD_SIZE       UINT32_C(512)
		/**
		 * POST_REQUEST_CUSTOM_HEADER_0 is a custom header which is sent along with the
		 * POST request. It's meant to demonstrate how to use custom header.
		 */
		#define POST_REQUEST_CUSTOM_HEADER_0    "X-AuthToken: InsertCrypticAuthenticationToken\r\n"
		
		/**
		 * POST_REQUEST_CUSTOM_HEADER_1 is a custom header which is sent along with the
		 * POST request. It's meant to demonstrate how to use custom header.
		 */
		#define POST_REQUEST_CUSTOM_HEADER_1    "X-Foobar: AnotherCustomHeader\r\n"
		
		#define POST_REQUEST_BODY               "{ \"device\": \"XDK110\", \"ping\": \"pong\" }"
		
		/**
		 * The time we wait (in milliseconds) between sending HTTP requests.
		 */
		#define INTER_REQUEST_INTERVAL          UINT32_C(10000)
		
		static HTTPRestClient_Setup_T HTTPRestClientSetupInfo =
		{
			.IsSecure = HTTP_SECURE_ENABLE,
		};
		
		#if HTTP_SECURE_ENABLE
		/**< SNTP setup parameters */
		static SNTP_Setup_T SNTPSetupInfo =
		{
		    .ServerUrl = SNTP_SERVER_URL,
		    .ServerIpAddr = SNTP_SERVER_IP_ADDR,
		    .ServerPort = «port»,
		    .UseServerUrl = SNTP_USE_SERVER_URL,
		};
		/**
		 * SNTP_SERVER_URL is the SNTP server URL. Is unused if SNTP_USE_SERVER_URL is false.
		 */
		#define SNTP_SERVER_URL                 "YourSNTPServerURL"
		
		/**
		 * SNTP_SERVER_IP_ADDR is the SNTP server IP address. Is unused if SNTP_USE_SERVER_URL is true.
		 */
		#define SNTP_SERVER_IP_ADDR             BCDS_IPV4_VAL(0, 0, 0, 0)
		
		/**
		 * SNTP_USE_SERVER_URL is a boolean.
		 * If true, then SNTP_SERVER_URL is to be used for retrieving the SNTP server IP address. SNTP_SERVER_IP_ADDR macro is unused.
		 * If false, then SNTP_SERVER_IP_ADDR is used directly and SNTP_SERVER_URL macro is unused.
		 *
		 */
		#define SNTP_USE_SERVER_URL             false		
		#endif /* HTTP_SECURE_ENABLE */
		
		''')
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
	
}