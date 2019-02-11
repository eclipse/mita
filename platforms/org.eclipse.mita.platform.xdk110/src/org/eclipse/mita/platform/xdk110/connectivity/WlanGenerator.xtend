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
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator.LogLevel
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer.SumTypeRepr
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.generator.GeneratorUtils

class WlanGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject
	protected extension GeneratorUtils
	
	@Inject(optional=true)
	protected IPlatformLoggingGenerator loggingGenerator
	
	override generateSetup() {
		CodeFragment.EMPTY;
	}
	
	@Inject
	protected extension StatementGenerator statementGenerator
			
	override generateEnable() {
	
		val ipConfigExpr = StaticValueInferrer.infer(configuration.getExpression("ipConfiguration"), []);
		val auth = StaticValueInferrer.infer(configuration.getExpression("authentication"), []);
		val result = codeFragmentProvider.create('''
		
		Retcode_T retcode = RETCODE_OK;

		/* The order of calls is important here. WlanConnect_init initializes the CC3100 and prepares
		 * its future use. Calls to NetworkConfig_ fail if WlanConnect_Init was not called beforehand.
		 */
		retcode = WlanConnect_Init(«baseName»_StatusCallback);

		if(RETCODE_OK != retcode)
		{
			return retcode;
		}
		«IF ipConfigExpr instanceof SumTypeRepr»
			«IF ipConfigExpr.name.contains("Dhcp")»
				retcode = NetworkConfig_SetIpDhcp(NULL);
				if (RETCODE_OK != retcode)
				{
					return retcode;
				}
			«ELSEIF ipConfigExpr.name == "Static"»
				NetworkConfig_IpSettings_T staticIpSettings;
				staticIpSettings.isDHCP = false;
				staticIpSettings.ipV4          = sl_Htonl(XDK_NETWORK_IPV4(«(StaticValueInferrer.infer(ipConfigExpr.properties.get("ip"),         []) as String)?.split("\\.")?.join(", ")»));
				staticIpSettings.ipV4Mask      = sl_Htonl(XDK_NETWORK_IPV4(«(StaticValueInferrer.infer(ipConfigExpr.properties.get("subnetMask"), []) as String)?.split("\\.")?.join(", ")»));
				staticIpSettings.ipV4Gateway   = sl_Htonl(XDK_NETWORK_IPV4(«(StaticValueInferrer.infer(ipConfigExpr.properties.get("gateway"),    []) as String)?.split("\\.")?.join(", ")»));
				staticIpSettings.ipV4DnsServer = sl_Htonl(XDK_NETWORK_IPV4(«(StaticValueInferrer.infer(ipConfigExpr.properties.get("dns"),        []) as String)?.split("\\.")?.join(", ")»));
				
				retcode = NetworkConfig_SetIpStatic(staticIpSettings);
				if (RETCODE_OK != retcode)
				{
					return retcode;
				}
			«ENDIF»
		«ELSE»
			ERROR: INVALID CONFIGURATION: ipConfiguration
		«ENDIF»
		
		«IF auth instanceof SumTypeRepr»
			«IF auth.name == "None"»
				/* Passing NULL as onConnection callback (last parameter) makes this a blocking call, i.e. the
				 * WlanConnect_Open function will return only once a connection to the WLAN has been established,
				 * or if something went wrong while trying to do so. If you wanted non-blocking behavior, pass
				 * a callback instead of NULL. */
				«loggingGenerator.generateLogStatement(LogLevel.Info, "Connecting to open network: %s", codeFragmentProvider.create('''NETWORK_SSID'''))»
				retcode = WlanConnect_Open((WlanConnect_SSID_T) NETWORK_SSID, true);
				if(RETCODE_OK != retcode)
				{
					return retcode;
				}
			«ELSEIF auth.name == "Personal"»
				/* Passing NULL as onConnection callback (last parameter) makes this a blocking call, i.e. the
				 * WlanConnect_WPA function will return only once a connection to the WLAN has been established,
				 * or if something went wrong while trying to do so. If you wanted non-blocking behavior, pass
				 * a callback instead of NULL. */
				«loggingGenerator.generateLogStatement(LogLevel.Info, "Connecting to personal network: %s", codeFragmentProvider.create('''NETWORK_SSID'''))»
				retcode = WlanConnect_WPA((WlanConnect_SSID_T) NETWORK_SSID, (WlanConnect_PassPhrase_T) NETWORK_PSK, true);
				if(RETCODE_OK != retcode)
				{
					return retcode;
				}
			«ELSEIF auth.name == "Enterprise"»
				«IF configuration.getBoolean("isHostPgmEnabled")»
					«loggingGenerator.generateLogStatement(LogLevel.Info, "Connecting to enterprise network with host programming: %s", codeFragmentProvider.create('''NETWORK_SSID'''))»
					retcode = WLANHostPgm_Enable();
					if(RETCODE_OK != retcode)
					{
						return retcode;
					}
				«ELSE»
					«loggingGenerator.generateLogStatement(LogLevel.Info, "Connecting to enterprise network without host programming: %s", codeFragmentProvider.create('''NETWORK_SSID'''))»
				«ENDIF»
				/* disable server authentication */
				unsigned char pValues;
				pValues = 0; //0 - Disable the server authentication | 1 - Enable (this is the default)
				if (0U != sl_WlanSet(SL_WLAN_CFG_GENERAL_PARAM_ID, 19, 1, &pValues))
				{
					return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_WLAN_SL_SET_FAILED);
				}
				
				/* Passing NULL as onConnection callback (last parameter) makes this a blocking call, i.e. the
				 * WlanConnect_EnterpriseWPA function will return only once a connection to the WLAN has been established,
				 * or if something went wrong while trying to do so. If you wanted non-blocking behavior, pass
				 * a callback instead of NULL. */
				retcode = WlanConnect_EnterpriseWPA((WlanConnect_SSID_T) NETWORK_SSID, (WlanConnect_Username_T) NETWORK_USERNAME, (WlanConnect_PassPhrase_T) NETWORK_PASSWORD, true);
				if(RETCODE_OK != retcode)
				{
					return retcode;
				}
				else
				{
					vTaskDelay(pdMS_TO_TICKS(1000));
				}
			«ENDIF»
		«ELSE»
			ERROR: INVALID CONFIGURATION: authentication
		«ENDIF»
		
		

		NetworkConfig_IpSettings_T currentIpSettings;
		retcode = NetworkConfig_GetIpSettings(&currentIpSettings);
		if(RETCODE_OK != retcode)
		{
			return retcode;
		}
		else
		{
			uint32_t ipAddress = Basics_htonl(currentIpSettings.ipV4);
		
			char humanReadableIpAddress[SERVAL_IP_ADDR_LEN] = { 0 };
			int conversionStatus = Ip_convertAddrToString(&ipAddress, humanReadableIpAddress);
			if (conversionStatus < 0)
			{
				«loggingGenerator.generateLogStatement(LogLevel.Warning, "Couldn't convert the IP address to string format")»
			}
			else
			{
				«loggingGenerator.generateLogStatement(LogLevel.Info, "Connected to WLAN. IP address of this device is: %s", codeFragmentProvider.create('''humanReadableIpAddress'''))»
			}
		}
		
		return RETCODE_OK;
		''')
		.setPreamble('''
		#define NETWORK_SSID  "«configuration.getString("ssid")»"
		«IF auth instanceof SumTypeRepr»
			«IF auth.name == "Personal"»
				#define NETWORK_PSK  «auth.properties.get("psk").code»
			«ELSEIF auth.name == "Enterprise"»
				#define NETWORK_USERNAME «auth.properties.get("username").code»
				#define NETWORK_PASSWORD «auth.properties.get("password").code»
			«ENDIF»
		«ELSE»
			ERROR: INVALID CONFIGURATION: authentication
		«ENDIF»
		«setup.buildStatusCallback(eventHandler)»
		
		''')
		.addHeader('XdkCommonInfo.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
		.addHeader('BCDS_WlanConnect.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('BCDS_NetworkConfig.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('Serval_Network.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('Serval_Ip.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('wlan.h', true, IncludePath.HIGH_PRIORITY)
		if(auth instanceof SumTypeRepr) {
			if(auth.name == "Enterprise") {
				result.addHeader('WLANHostPgm.h', true, IncludePath.HIGH_PRIORITY)		
			}
		}
		if(ipConfigExpr instanceof SumTypeRepr) {
			if(ipConfigExpr.name == "Static") {
				result.addHeader("XDK_Utils.h", true)
			}
		}
		return result
	}
	private def CodeFragment buildStatusCallback(SystemResourceSetup component, Iterable<EventHandlerDeclaration> declarations) {
						val baseName = component.baseName
				
				codeFragmentProvider.create('''
				static void «baseName»_StatusCallback(WlanConnect_Status_T connectStatus)
				{
					BCDS_UNUSED(connectStatus);
				}
				
				''')
			}
}
