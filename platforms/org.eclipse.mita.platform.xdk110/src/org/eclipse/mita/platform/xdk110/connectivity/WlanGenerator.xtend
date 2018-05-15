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

import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import com.google.inject.Inject
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator.LogLevel

class WlanGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject(optional=true)
	protected IPlatformLoggingGenerator loggingGenerator
	
	override generateSetup() {
		CodeFragment.EMPTY
	}

	override generateEnable() {
		codeFragmentProvider.create('''
		Retcode_T retcode;
		
		retcode = WlanConnect_Init();
		if(RETCODE_OK != retcode)
		{
			return retcode;
		}
		
		/* The order of calls is important here. WlanConnect_init initializes the CC3100 and prepares
		 * its future use. Calls to NetworkConfig_ fail if WlanConnect_Init was not called beforehand.
		 */
		«IF configuration.getBoolean("useDHCP")»
		retcode = NetworkConfig_SetIpDhcp(NULL);
		if (RETCODE_OK != retcode)
		{
			return retcode;
		}
		«ELSE»
		NetworkConfig_IpSettings_T staticIpSettings;
		staticIpSettings.isDHCP = false;
		if(Ip_convertStringToAddr("«configuration.getString("staticIP")»", &staticIpSettings.ipV4) != RC_OK) return EXCEPTION_EXCEPTION;
		if(Ip_convertStringToAddr("«configuration.getString("staticMask")»", &staticIpSettings.ipV4Mask) != RC_OK) return EXCEPTION_EXCEPTION;
		if(Ip_convertStringToAddr("«configuration.getString("staticGW")»", &staticIpSettings.ipV4Gateway) != RC_OK) return EXCEPTION_EXCEPTION;
		if(Ip_convertStringToAddr("«configuration.getString("staticDNS")»", &staticIpSettings.ipV4DnsServer) != RC_OK) return EXCEPTION_EXCEPTION;
		
		retcode = NetworkConfig_SetIpStatic(staticIpSettings);
		if (RETCODE_OK != retcode)
		{
			return retcode;
		}
		«ENDIF»
	
		«IF configuration.getBoolean("enterprise")»
		«loggingGenerator.generateLogStatement(LogLevel.Info, "Connecting to enterprise network: %s", codeFragmentProvider.create('''NETWORK_SSID'''))»
		«IF configuration.getBoolean("isHostPgmEnabled")»
		«loggingGenerator.generateLogStatement(LogLevel.Info, "Connecting to enterprise network with host programming")»
		retcode = WLANHostPgm_Enable();
		if(RETCODE_OK != retcode)
		{
			return retcode;
		}

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
		retcode = WlanConnect_EnterpriseWPA((WlanConnect_SSID_T) NETWORK_SSID, (WlanConnect_Username_T) NETWORK_USERNAME, (WlanConnect_PassPhrase_T) NETWORK_PSK, NULL);
		if(RETCODE_OK != retcode)
		{
			return retcode;
		}
		else
		{
			vTaskDelay(pdMS_TO_TICKS(1000));
		}
		«ELSE»
		«loggingGenerator.generateLogStatement(LogLevel.Info, "Connecting to enterprise network without host programming")»
		«ENDIF»
		«ELSE»
		/* Passing NULL as onConnection callback (last parameter) makes this a blocking call, i.e. the
		 * WlanConnect_WPA function will return only once a connection to the WLAN has been established,
		 * or if something went wrong while trying to do so. If you wanted non-blocking behavior, pass
		 * a callback instead of NULL. */
		«loggingGenerator.generateLogStatement(LogLevel.Info, "Connecting to personal network: %s", codeFragmentProvider.create('''NETWORK_SSID'''))»
		retcode = WlanConnect_WPA((WlanConnect_SSID_T) NETWORK_SSID, (WlanConnect_PassPhrase_T) NETWORK_PSK, NULL);
		if(RETCODE_OK != retcode)
		{
			return retcode;
		}
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
		#define NETWORK_PSK  "«configuration.getString("psk")»"
		#define NETWORK_USERNAME "«configuration.getString("username")»"
		''')
		.addHeader('XdkCommonInfo.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
		.addHeader('BCDS_WlanConnect.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('BCDS_NetworkConfig.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('WLANHostPgm.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('Serval_Network.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('Serval_Ip.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('wlan.h', true, IncludePath.HIGH_PRIORITY)
	}
	
}
