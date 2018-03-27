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
		retcode_t servalRetcode;
		
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
		
		«loggingGenerator.generateLogStatement(LogLevel.Info, "Connecting to %s", codeFragmentProvider.create('''NETWORK_SSID'''))»
		/* Passing NULL as onConnection callback (last parameter) makes this a blocking call, i.e. the
		 * WlanConnect_WPA function will return only once a connection to the WLAN has been established,
		 * or if something went wrong while trying to do so. If you wanted non-blocking behavior, pass
		 * a callback instead of NULL. */
		retcode = WlanConnect_WPA((WlanConnect_SSID_T) NETWORK_SSID, (WlanConnect_PassPhrase_T) NETWORK_PSK, NULL);
		if(RETCODE_OK != retcode)
		{
			return retcode;
		}
		
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
		#define NETWORK_SSID "«configuration.getString("ssid")»"
		#define NETWORK_PSK  "«configuration.getString("psk")»"
		''')
		.addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
		.addHeader('BCDS_WlanConnect.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('BCDS_NetworkConfig.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('Serval_Network.h', true, IncludePath.HIGH_PRIORITY)
		.addHeader('Serval_Ip.h', true, IncludePath.HIGH_PRIORITY)
	}
	
}
