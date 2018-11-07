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
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.GeneratorUtils

class Bme280Generator extends AbstractSystemResourceGenerator {
    
    public static final String CONFIG_ITEM_POWER_MODE = 'power_mode';
    public static final String CONFIG_ITEM_STANDBY_TIME = 'standby_time';
    public static final String CONFIG_ITEM_TEMPERATURE_OVERSAMPLING = 'temperature_oversampling';
    public static final String CONFIG_ITEM_PRESSURE_OVERSAMPLING = 'pressure_oversampling';
    public static final String CONFIG_ITEM_HUMIDITY_OVERSAMPLING = 'humidity_oversampling';
    
    @Inject
    protected extension GeneratorUtils
    
    @Inject
	protected CodeFragmentProvider codeFragmentProvider
    
    override generateSetup() {
        val powerMode = if(configuration.getEnumerator(CONFIG_ITEM_POWER_MODE)?.name == 'Forced') 'ENVIRONMENTAL_BME280_POWERMODE_FORCED' else 'ENVIRONMENTAL_BME280_POWERMODE_NORMAL';
        val standbyTimeRaw = configuration.getInteger(CONFIG_ITEM_STANDBY_TIME);
        val standbyTime = if(standbyTimeRaw === null) null else standbyTimeRaw.clipStandbyTime?.value;
        val temperatureOversampling = configuration.getEnumerator(CONFIG_ITEM_TEMPERATURE_OVERSAMPLING)?.oversamplingConstant;
        val pressureOversampling = configuration.getEnumerator(CONFIG_ITEM_PRESSURE_OVERSAMPLING)?.oversamplingConstant;
        val humidityOversampling = configuration.getEnumerator(CONFIG_ITEM_HUMIDITY_OVERSAMPLING)?.oversamplingConstant;
        
        
        codeFragmentProvider.create('''
        Retcode_T exception = RETCODE_OK;
        
        exception = Environmental_init(xdkEnvironmental_BME280_Handle);
        «generateExceptionHandler(component, 'exception')»
        
        exception = Environmental_setPowerMode(xdkEnvironmental_BME280_Handle, «powerMode»);
        «generateExceptionHandler(component, 'exception')»
        «IF standbyTime !== null»
        
        exception = Environmental_setStandbyDuration(xdkEnvironmental_BME280_Handle, «standbyTime»);
        «generateExceptionHandler(component, 'exception')»
        «ENDIF»
        «IF temperatureOversampling !== null»
        
        exception = Environmental_setOverSamplingTemperature(xdkEnvironmental_BME280_Handle, «temperatureOversampling»);
        «generateExceptionHandler(component, 'exception')»
        «ENDIF»
        «IF pressureOversampling !== null»
        
        exception = Environmental_setOverSamplingPressure(xdkEnvironmental_BME280_Handle, «pressureOversampling»);
        «generateExceptionHandler(component, 'exception')»
        «ENDIF»
        «IF humidityOversampling !== null»
        
        exception = Environmental_setOverSamplingHumidity(xdkEnvironmental_BME280_Handle, «humidityOversampling»);
        «generateExceptionHandler(component, 'exception')»
        «ENDIF»
        ''')
        .addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
        .addHeader('BCDS_Retcode.h', true, IncludePath.HIGH_PRIORITY)
        .addHeader('BCDS_Environmental.h', true)
        .addHeader('XdkSensorHandle.h', true)
    }
    
    protected def String getOversamplingConstant(Enumerator value) {
        return switch(value?.name) {
            case 'OVERSAMPLE_1X': 'ENVIRONMENTAL_BME280_OVERSAMP_1X'
            case 'OVERSAMPLE_2X': 'ENVIRONMENTAL_BME280_OVERSAMP_2X'
            case 'OVERSAMPLE_4X': 'ENVIRONMENTAL_BME280_OVERSAMP_4X'
            case 'OVERSAMPLE_8X': 'ENVIRONMENTAL_BME280_OVERSAMP_8X'
            case 'OVERSAMPLE_16X': 'ENVIRONMENTAL_BME280_OVERSAMP_16X'
            default: null
        }
    }
    
    override generateEnable() {
        return CodeFragment.EMPTY;
    }
    
	override generateAccessPreparationFor(ModalityAccessPreparation accessPreparation) {
		return codeFragmentProvider.create('''
        Environmental_Data_T «accessPreparation.dataVariable»;
        exception = Environmental_readData(xdkEnvironmental_BME280_Handle, &«accessPreparation.dataVariable»);
        «generateExceptionHandler(component, 'exception')»
        ''')
        .addHeader('BCDS_Environmental.h', true)
        .addHeader('XdkSensorHandle.h', true)
    }
	
	def String getDataVariable(ModalityAccessPreparation preparation) {
		return preparation.uniqueIdentifier.toFirstLower;
	}
    
	override generateModalityAccessFor(ModalityAccess modalityAccess) {
		val dataVariable = modalityAccess.preparation.dataVariable;
		val modalityName = modalityAccess.modality.name;
        
        return switch(modalityName) {
            case 'temperature': codeFragmentProvider.create('''«dataVariable».temperature''')
            case 'pressure': codeFragmentProvider.create('''«dataVariable».pressure''')
            case 'humidity': codeFragmentProvider.create('''((float)«dataVariable».humidity)''')
            case 'humidity_fixed_point': codeFragmentProvider.create('''«dataVariable».humidity''')
        }
    }
    
    /**
     * Translates an arbitrary standby time in milliseconds to a fixed, supported value.
     */
    public static def Pair<Integer, String> clipStandbyTime(int standbyTime) {
        val supportedValuesInMs = #[1, 10, 20, 63, 125, 250, 500, 1000];
        val nearestStandbyTime = supportedValuesInMs.minBy[x| Math.abs(x - standbyTime)];
        val constantName = '''ENVIRONMENTAL_BME280_STANDBY_TIME_«nearestStandbyTime»_MS''';
        return nearestStandbyTime -> constantName;
    }
    
}