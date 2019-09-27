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

package org.eclipse.mita.platform.xdk110.sensors

import com.google.inject.Inject
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.GeneratorUtils

class Max44009Generator extends AbstractSystemResourceGenerator {
    
    public static final String CONFIG_ITEM_HIGH_BRIGHTNESS = 'high_brightness';
    public static final String CONFIG_ITEM_INTEGRATION_TIME = 'integration_time';
    public static final String CONFIG_ITEM_MANUAL_MODE = 'manual_mode';
    public static final String CONFIG_ITEM_CONTINUOUS_MODE = 'continuous_mode';
    
    @Inject
    protected extension GeneratorUtils
    
    @Inject
	protected CodeFragmentProvider codeFragmentProvider
    
    override generateSetup() {
        val manualMode = configuration.getBoolean(CONFIG_ITEM_MANUAL_MODE) ?: false;
        val integrationTime = switch(configuration.getEnumerator(CONFIG_ITEM_INTEGRATION_TIME)?.name) {
            case 'MS_800': 'LIGHTSENSOR_800_MS'
            case 'MS_400': 'LIGHTSENSOR_400MS'
            case 'MS_200': 'LIGHTSENSOR_200MS'
            case 'MS_100': 'LIGHTSENSOR_100MS'
            case 'MS_50': 'LIGHTSENSOR_50MS'
            case 'MS_25': 'LIGHTSENSOR_25MS'
            case 'MS_12_5': 'LIGHTSENSOR_12P5MS'
            case 'MS_6_25': 'LIGHTSENSOR_6P5MS'
            default: null
        }
        val highBrightness = configuration.getBoolean(CONFIG_ITEM_HIGH_BRIGHTNESS) ?: false;
        val continuousMode = configuration.getBoolean(CONFIG_ITEM_CONTINUOUS_MODE) ?: false;
        
        val manualModeCommentLine = if(manualMode) '' else '// '
        
        codeFragmentProvider.create('''
        Retcode_T exception = RETCODE_OK;

        exception = LightSensor_init(xdkLightSensor_MAX44009_Handle);
        «generateExceptionHandler(component, 'exception')»
        
        // Configure manual mode«IF manualMode», brightness and integration time«ENDIF»
        exception = LightSensor_setManualMode(xdkLightSensor_MAX44009_Handle, «IF manualMode»LIGHTSENSOR_MAX44009_ENABLE_MODE«ELSE»LIGHTSENSOR_MAX44009_DISABLE_MODE«ENDIF»);
        «generateExceptionHandler(component, 'exception')»
        «IF !manualMode»
        
        /*
         * Integration time and high-brightness are automatically choosen by the sensor because manual mode is disabled.
         */
        «ENDIF»
        «manualModeCommentLine»exception = LightSensor_setBrightness(xdkLightSensor_MAX44009_Handle, «IF highBrightness»LIGHTSENSOR_HIGH_BRIGHTNESS«ELSE»LIGHTSENSOR_NORMAL_BRIGHTNESS«ENDIF»);
        «manualModeCommentLine»«generateExceptionHandler(component, 'exception')»
        «IF integrationTime !== null»
        «manualModeCommentLine»exception = LightSensor_setIntegrationTime(xdkLightSensor_MAX44009_Handle, «integrationTime»);
        «manualModeCommentLine»«generateExceptionHandler(component, 'exception')»
        «ENDIF»
        
        // Configure continuous mode
        exception = LightSensor_setContinuousMode(xdkLightSensor_MAX44009_Handle, «IF continuousMode»LIGHTSENSOR_MAX44009_ENABLE_MODE«ELSE»LIGHTSENSOR_MAX44009_DISABLE_MODE«ENDIF»);
        «generateExceptionHandler(component, 'exception')»
        ''')
        .addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
        .addHeader('BCDS_Retcode.h', true, IncludePath.HIGH_PRIORITY)
        .addHeader('XdkSensorHandle.h', true)
        .addHeader('BCDS_LightSensor.h', true)
    }
    
    override generateEnable() {
        CodeFragment.EMPTY
    }
    
	override generateAccessPreparationFor(ModalityAccessPreparation accessPreparation) {
		val variableName = accessPreparation.uniqueIdentifier.toFirstLower;
        
        codeFragmentProvider.create('''
        uint32_t «variableName»;
        exception = LightSensor_readLuxData(xdkLightSensor_MAX44009_Handle, &«variableName»);
        «generateExceptionHandler(component, 'exception')»
        ''')
        .addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
        .addHeader('BCDS_Retcode.h', true, IncludePath.HIGH_PRIORITY)
        .addHeader('XdkSensorHandle.h', true)
        .addHeader('BCDS_LightSensor.h', true)
    }
    
	override generateModalityAccessFor(ModalityAccess modality) {
		codeFragmentProvider.create('''«modality.preparation.uniqueIdentifier.toFirstLower»''');
    }
    
}