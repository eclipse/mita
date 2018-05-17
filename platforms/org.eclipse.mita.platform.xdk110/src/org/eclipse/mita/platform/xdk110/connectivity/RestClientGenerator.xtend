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
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator.LogLevel
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
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject(optional=true)
	protected IPlatformLoggingGenerator loggingGenerator

	override generateSignalInstanceSetter(SignalInstance signalInstance, String variableName) {
		val baseUrl = new URL(configuration.getString("endpointBase"));
		val url = StaticValueInferrer.infer(ModelUtils.getArgumentValue(signalInstance, "endpoint"), [ ]);
		val httpMethod = ModelUtils.getArgumentValue(signalInstance, "writeMethod").httpMethod;
		val contentType = StaticValueInferrer.infer(ModelUtils.getArgumentValue(signalInstance, "contentType"), []);
		val port = if(baseUrl.port < 0) 80 else baseUrl.port;
		
		codeFragmentProvider.create('''
		size_t messageLength = strlen((const char*) *«variableName»);
		if(messageLength > sizeof(httpBodyBuffer))
		{
			return EXCEPTION_INDEXOUTOFBOUNDSEXCEPTION;
		}
		
		memcpy(httpBodyBuffer, *«variableName», strlen(*«variableName»));
		
		/**< HTTP rest client configuration parameters */
		static HTTPRestClient_Config_T HTTPRestClientConfigInfo =
		{
		       .IsSecure = configuration.getBoolean("isSecurityEnabled"),
		       .DestinationServerUrl = url,
		       .DestinationServerPort = port,
		       .RequestMaxDownloadSize = REQUEST_MAX_DOWNLOAD_SIZE,
		};

		/**< HTTP rest client POST parameters */
		static HTTPRestClient_Post_T HTTPRestClientPostInfo =
		{
		       .Payload = POST_REQUEST_BODY, //TODO: check whether we get the payload
		       .PayloadLength = (sizeof(POST_REQUEST_BODY) - 1U),
		       .Url = httpMethod,
		       .RequestCustomHeader0 = POST_REQUEST_CUSTOM_HEADER_0,
		       .RequestCustomHeader1 = POST_REQUEST_CUSTOM_HEADER_1,
		};
		retcode_t rc = HTTPRestClient_Post(&HTTPRestClientConfigInfo, &HTTPRestClientPostInfo, APP_RESPONSE_FROM_HTTP_SERVER_POST_TIMEOUT); 
		//TODO: this is post; where to get. What is the application of restclient ? 
		// 1. for the user to post and get
		return retcode;
		''')
		.setPreamble('''
		#define APP_RESPONSE_FROM_HTTP_SERVER_POST_TIMEOUT  UINT32_C(10000)"
		#define REQUEST_MAX_DOWNLOAD_SIZE       UINT32_C(512)
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
	
	override generateSetup() {
		codeFragmentProvider.create('''
		static CmdProcessor_T * AppCmdProcessor;

		static SNTP_Setup_T SNTPSetupInfo =
		{
		    .ServerUrl = SNTP_SERVER_URL,
		    .ServerIpAddr = SNTP_SERVER_IP_ADDR,
		    .ServerPort = SNTP_SERVER_PORT,
		    .UseServerUrl = SNTP_USE_SERVER_URL,
		};
		static HTTPRestClient_Setup_T HTTPRestClientSetupInfo =
		{
			.IsSecure = HTTP_SECURE_ENABLE,
		};

		Retcode_T retcode = ServalPAL_Setup(AppCmdProcessor);
		«IF configuration.getBoolean("isSecurityEnabled")»
		if (RETCODE_OK == retcode)
		{
		    retcode = SNTP_Setup(&SNTPSetupInfo);
		}
		«ENDIF»
		if (RETCODE_OK == retcode)
		{
		    retcode = HTTPRestClient_Setup(&HTTPRestClientSetupInfo);
		}
		if (RETCODE_OK != retcode)
		{
			return retcode;
		}
		''')
	}
	
	override generateEnable() {
		codeFragmentProvider.create('''

		Retcode_T retcode = ServalPAL_Enable();
		if (retcode != RETCODE_OK)
		{
		    return retcode;
		}
		«IF configuration.getBoolean("isSecurityEnabled")»
		if (RETCODE_OK == retcode)
		{
		    retcode = SNTP_Enable();
		}
		«ENDIF»
		if (RETCODE_OK == retcode)
		{
		    retcode = HTTPRestClient_Enable();
		}

		if (RETCODE_OK != retcode)
		{
			return retcode;
		}
		''')
		.addHeader("BCDS_Basics.h", true, IncludePath.HIGH_PRIORITY)
		.addHeader('XDK_ServalPAL.h', true)
		.addHeader('XDK_SNTP.h', true)
		.addHeader('XDK_HTTPRestClient.h', true)
	}
	
}