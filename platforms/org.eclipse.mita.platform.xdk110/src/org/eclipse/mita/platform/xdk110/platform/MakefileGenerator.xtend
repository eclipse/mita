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

package org.eclipse.mita.platform.xdk110.platform

import java.util.List
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.PlatformMakefileGenerator
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import java.util.ArrayList
import java.util.HashSet

class MakefileGenerator extends PlatformMakefileGenerator {	
	override generateMakefile(CompilationContext context, List<String> sourceFiles) {
		val compilationUnits = context.allUnits
		val setups = compilationUnits?.flatMap[it.setup];
		val appName = StaticValueInferrer.infer(
			setups?.findFirst[it.type.name == "XDK110"]?.getConfigurationItemValue("applicationName"), []
		)?: "EclipseMitaApplication"
		val isSecure = (StaticValueInferrer.infer(
			setups?.findFirst[it.type.name == "MQTT" || it.type.name == "HonoMqtt"]?.getConfigurationItemValue("url"), []
		) as String ?: "").startsWith("mqtts");
		return codeFragmentProvider.create('''
		# This makefile triggers the targets in the application.mk
		
		# The default value "../../.." assumes that this makefile is placed in the 
		# folder xdk110/Apps/<App Folder> where the BCDS_BASE_DIR is the parent of 
		# the xdk110 folder.
		BCDS_BASE_DIR ?= ../../..
		
		# Macro to define Start-up method. change this macro to "CUSTOM_STARTUP" to have custom start-up.
		export BCDS_SYSTEM_STARTUP_METHOD = DEFAULT_STARTUP
		export BCDS_APP_NAME = «appName»
		export BCDS_APP_DIR = $(CURDIR)
		export BCDS_APP_SOURCE_DIR = $(BCDS_APP_DIR)
		
		#Please refer BCDS_CFLAGS_COMMON variable in application.mk file
		#and if any addition flags required then add that flags only in the below macro 
		#export BCDS_CFLAGS_COMMON = 
		
		«IF isSecure»
		export SERVAL_TLS_MBEDTLS=1
		export SERVAL_ENABLE_TLS_CLIENT=1
		export SERVAL_ENABLE_TLS_ECC=1
		export SERVAL_ENABLE_TLS_PSK=0
		export SERVAL_MAX_NUM_MESSAGES=8
		export SERVAL_MAX_SIZE_APP_PACKET=900
		export SERVAL_ENABLE_TLS=1
		
		export XDK_MBEDTLS_PARSE_INFO=0
		«ENDIF»
		
		#List all the application header file under variable BCDS_XDK_INCLUDES 
		export BCDS_XDK_INCLUDES = \
			-I$(BCDS_BASE_DIR)/xdk110/Libraries/BSTLib/3rd-party/bstlib/BMA2x2_driver \
			-I$(BCDS_BASE_DIR)/xdk110/Platform/BSP/source \
			-I$(BCDS_APP_SOURCE_DIR) \
			-I$(BCDS_APP_SOURCE_DIR)/.. \
			-I$(BCDS_APP_SOURCE_DIR)/base \
			-I$(BCDS_BASE_DIR)/xdk110/Common/include \
			-I$(BCDS_BASE_DIR)/xdk110/Common/certs/XDKDummy \
			-I$(BCDS_BASE_DIR)/xdk110/Common/source/Private/ServalStack/src/TLS_MbedTLS \
			-I$(BCDS_BASE_DIR)/xdk110/Common/source \
			-I$(BCDS_BASE_DIR)/xdk110/Common/source/Connectivity \
			-I$(BCDS_BASE_DIR)/xdk110/Platform/BSP/source
			
		#List all the application source file under variable BCDS_XDK_APP_SOURCE_FILES in a similar pattern as below
		export BCDS_XDK_APP_SOURCE_FILES = \
			«new HashSet(sourceFiles).filter[x | x.endsWith('.c') ].map[x | '''$(BCDS_APP_SOURCE_DIR)/«x»'''].sort.join(' \\\n')»
		
		.PHONY: clean debug release flash_debug_bin flash_release_bin
		
		clean: 
			$(MAKE) -C $(BCDS_BASE_DIR)/xdk110/Common -f application.mk clean
		
		debug: 
			$(MAKE) -C $(BCDS_BASE_DIR)/xdk110/Common -f application.mk debug
			
		release: 
			$(MAKE) -C $(BCDS_BASE_DIR)/xdk110/Common -f application.mk release
			
		flash_debug_bin: 
			$(MAKE) -C $(BCDS_BASE_DIR)/xdk110/Common -f application.mk flash_debug_bin
			
		flash_release_bin: 
			$(MAKE) -C $(BCDS_BASE_DIR)/xdk110/Common -f application.mk flash_release_bin
		
		cleanlint: 
			$(MAKE) -C $(BCDS_BASE_DIR)/xdk110/Common -f application.mk cleanlint
			
		lint: 
			$(MAKE) -C $(BCDS_BASE_DIR)/xdk110/Common -f application.mk lint
		
		cdt:
			$(MAKE) -C $(BCDS_BASE_DIR)/xdk110/Common -f application.mk cdt	
		

	''')
	}
	
}