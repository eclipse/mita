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
		codeFragmentProvider.create('''
			Retcode_T exception = RETCODE_OK;

			«IF configuration.getBoolean("isHostPgmEnabled")»
			exception = WLANHostPgm_Setup();
			«generateLoggingExceptionHandler("WLAN host programming", "setting up")»
			«ENDIF»
			
			NetworkConfigSemaphore = xSemaphoreCreateBinary();
			if (NULL == NetworkConfigSemaphore)
			{
			    printf("Failed to create Semaphore \r\n");
			    return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
			}
			
			WlanEventSemaphore = xSemaphoreCreateBinary();
			if (NULL == WlanEventSemaphore)
			{
			    vSemaphoreDelete(NetworkConfigSemaphore);
			    printf("Failed to create Semaphore \r\n");
			    return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
			}
			
			return (exception);
		''')
		.setPreamble('''
			static SemaphoreHandle_t WlanEventSemaphore = NULL;
			static SemaphoreHandle_t NetworkConfigSemaphore = NULL;
		''')
		.addHeader("semphr.h", true);
	}
	
	@Inject
	protected extension StatementGenerator statementGenerator
			
	override generateEnable() {
		val baseName = setup.baseName
		val ipConfigExpr = StaticValueInferrer.infer(configuration.getExpression("ipConfiguration"), []);
		val auth = StaticValueInferrer.infer(configuration.getExpression("authentication"), []);
		val result = codeFragmentProvider.create('''
		
		Retcode_T exception = RETCODE_OK;

		/* Initialize the Wireless Network Driver */
		exception = WlanNetworkConnect_Init(«baseName»_WlanConnectStatusCallback);
		«generateLoggingExceptionHandler("WlanNetworkConnect", "init")»
		/* Semaphore take to flush the existing queue events without timeout. Hence no need to consider the return value */
		(void) xSemaphoreTake(WlanEventSemaphore, 0U);
				
		«IF ipConfigExpr instanceof SumTypeRepr»
			«IF ipConfigExpr.name.contains("Dhcp")»
				/* Semaphore take to flush the existing queue events without timeout. Hence no need to consider the return value */
				(void) xSemaphoreTake(NetworkConfigSemaphore, 0U);
				exception = WlanNetworkConfig_SetIpDhcp(«baseName»_NetworkIpConfigStatusCallback);
				«generateLoggingExceptionHandler("DHCP", "setting")»
			«ELSEIF ipConfigExpr.name == "Static"»
				WlanNetworkConfig_IpSettings_T staticIpSettings;
				staticIpSettings.isDHCP = false;
				staticIpSettings.ipV4          = sl_Htonl(XDK_NETWORK_IPV4(«(StaticValueInferrer.infer(ipConfigExpr.properties.get("ip"),         []) as String)?.split("\\.")?.join(", ")»));
				staticIpSettings.ipV4Mask      = sl_Htonl(XDK_NETWORK_IPV4(«(StaticValueInferrer.infer(ipConfigExpr.properties.get("subnetMask"), []) as String)?.split("\\.")?.join(", ")»));
				staticIpSettings.ipV4Gateway   = sl_Htonl(XDK_NETWORK_IPV4(«(StaticValueInferrer.infer(ipConfigExpr.properties.get("gateway"),    []) as String)?.split("\\.")?.join(", ")»));
				staticIpSettings.ipV4DnsServer = sl_Htonl(XDK_NETWORK_IPV4(«(StaticValueInferrer.infer(ipConfigExpr.properties.get("dns"),        []) as String)?.split("\\.")?.join(", ")»));
				
				exception = WlanNetworkConfig_SetIpStatic(staticIpSettings);
				«generateLoggingExceptionHandler("static IP", "setting")»
			«ENDIF»
		«ELSE»
			ERROR: INVALID CONFIGURATION: ipConfiguration
		«ENDIF»
		
		«IF auth instanceof SumTypeRepr»
			«IF auth.name == "None"»
				«loggingGenerator.generateLogStatement(LogLevel.Info, "Connecting to open network: %s", codeFragmentProvider.create('''NETWORK_SSID'''))»
				exception = WlanNetworkConnect_Open((WlanNetworkConnect_SSID_T) NETWORK_SSID);
				if(RETCODE_OK != exception)
				{
					return exception;
				}
			«ELSEIF auth.name == "Personal"»
				«loggingGenerator.generateLogStatement(LogLevel.Info, "Connecting to personal network: %s", codeFragmentProvider.create('''NETWORK_SSID'''))»
				exception = WlanNetworkConnect_PersonalWPA((WlanNetworkConnect_SSID_T) NETWORK_SSID, (WlanNetworkConnect_PassPhrase_T) NETWORK_PSK);
				if(RETCODE_OK != exception)
				{
					return exception;
				}
			«ELSEIF auth.name == "Enterprise"»
				«IF configuration.getBoolean("isHostPgmEnabled")»
					«loggingGenerator.generateLogStatement(LogLevel.Info, "Connecting to enterprise network with host programming: %s", codeFragmentProvider.create('''NETWORK_SSID'''))»
					exception = WLANHostPgm_Enable();
					«generateLoggingExceptionHandler("WLAN host programming", "enable")»
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
				
				exception = WlanNetworkConnect_EnterpriseWPA((WlanNetworkConnect_SSID_T) NETWORK_SSID, (WlanNetworkConnect_Username_T) NETWORK_USERNAME, (WlanNetworkConnect_PassPhrase_T) NETWORK_PASSWORD);
				if(RETCODE_OK != exception)
				{
					return exception;
				}
				else
				{
					vTaskDelay(pdMS_TO_TICKS(1000));
				}
			«ENDIF»
		«ELSE»
			ERROR: INVALID CONFIGURATION: authentication
		«ENDIF»
		
		«IF ipConfigExpr instanceof SumTypeRepr»
			«IF ipConfigExpr.name.contains("Dhcp")»
				if (pdTRUE == xSemaphoreTake(NetworkConfigSemaphore, 200000))
				{
				    exception = WlanEventSemaphoreHandle();
				}
				else
				{
				    exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				}
			«ELSEIF ipConfigExpr.name == "Static"»
				exception = WlanEventSemaphoreHandle();
			«ENDIF»
		«ENDIF»

		WlanNetworkConfig_IpSettings_T currentIpSettings;
		exception = WlanNetworkConfig_GetIpSettings(&currentIpSettings);
		if(RETCODE_OK != exception)
		{
			return exception;
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
				#define NETWORK_PSK  "«StaticValueInferrer.infer(auth.properties.get("psk"), [])»"
			«ELSEIF auth.name == "Enterprise"»
				#define NETWORK_USERNAME "«StaticValueInferrer.infer(auth.properties.get("username"), [])»"
				#define NETWORK_PASSWORD "«StaticValueInferrer.infer(auth.properties.get("password"), [])»"
			«ENDIF»
		«ELSE»
			ERROR: INVALID CONFIGURATION: authentication
		«ENDIF»
		
		«setup.buildStatusCallbacks()»
		
		static Retcode_T WlanEventSemaphoreHandle(void)
		{
		    Retcode_T exception = RETCODE_OK;
		    uint8_t count = 0;
		    if (pdTRUE == xSemaphoreTake(WlanEventSemaphore, 200000))
		    {
		        do
		        {
		            if ((WLANNWCNF_IPSTATUS_IPV4_AQRD == WlanNetworkConfig_GetIpStatus()) && (WLANNWCT_STATUS_CONNECTED == WlanNetworkConnect_GetStatus()))
		            {
		                exception = RETCODE_OK;
		            }
		            else
		            {
		                vTaskDelay(500);
		                count++;
		                exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_WLAN_CONNECT_FAILED);
		            }
		        } while ((RETCODE_OK != exception)
		                && (UINT8_C(5) >= count));
		    }
		    else
		    {
		        exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
		    }
		    return exception;
		}
		
		Retcode_T CheckWlanConnectivityAndReconnect(void)
		{
			Retcode_T exception = RETCODE_OK;
			    WlanNetworkConnect_ScanInterval_T scanInterval = 5;
			    WlanNetworkConnect_ScanList_T scanList;
			    WlanNetworkConnect_IpStatus_T nwStatus;
			    bool networkStatusFlag = false;
			
			    nwStatus = WlanNetworkConnect_GetIpStatus();
			
			    if (WLANNWCT_IPSTATUS_CT_AQRD != nwStatus)
			    {
			        printf("Checking for network availability and trying to connect again\n");
			        exception = WlanNetworkConnect_ScanNetworks(scanInterval, &scanList);
			
			        if (RETCODE_OK == exception)
			        {
			            for (int i = 0U; i < WLANNWCT_MAX_SCAN_INFO_BUF; i++)
			            {
			                if (0U == strcmp((char *) NETWORK_SSID, (char *) scanList.ScanData[i].Ssid))
			                {
			                    networkStatusFlag = true;
			                    printf("Network with SSID  %s is available\n", NETWORK_SSID);
			                    exception = «setup.baseName»_Enable();
			                    if (RETCODE_OK != exception)
			                    {
			                        printf("Not able to connect to the network\n");
			                    }
			                    break;
			                }
			                else
			                {
			                    networkStatusFlag = false;
			                }
			            }
			            if (false == networkStatusFlag)
			            {
			                exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_WLAN_NETWORK_NOT_AVAILABLE);
			                printf("Network with SSID  %s is not available\n", NETWORK_SSID);
			            }
			        }
			        else if ((uint32_t) RETCODE_NO_NW_AVAILABLE == Retcode_GetCode(exception))
			        {
			            printf("Network not available\n");
			        }
			    }
			    else
			    {
			        printf("Network Connection is active\n");
			    }
			    return exception;
		}
		''')
		.addHeader('XdkCommonInfo.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
		.addHeader('BCDS_Wlan.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('BCDS_WlanNetworkConfig.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('Serval_Network.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('Serval_Ip.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader("BCDS_WlanNetworkConnect.h", true)
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
	
	override generateAdditionalHeaderContent() {
		return codeFragmentProvider.create('''
		Retcode_T CheckWlanConnectivityAndReconnect(void);
		''');
	}
	
	private def CodeFragment buildStatusCallbacks(SystemResourceSetup component) {
		val baseName = component.baseName
		
		return codeFragmentProvider.create('''
		static void «baseName»_WlanConnectStatusCallback(WlanNetworkConnect_Status_T connectStatus)
		{
			BCDS_UNUSED(connectStatus);
			(void) xSemaphoreGive(WlanEventSemaphore);
		}
		static void «baseName»_NetworkIpConfigStatusCallback(WlanNetworkConfig_IpStatus_T ipStatus)
		{
			BCDS_UNUSED(ipStatus);
			(void) xSemaphoreGive(NetworkConfigSemaphore);
		}
		''')
	}
}
