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

package org.eclipse.mita.platform.cgw.sensors

import com.google.inject.Inject
import org.eclipse.mita.base.types.Singleton
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.GeneratorUtils
import java.util.Map

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
    	val standbyTimeRaw = configuration.getLong(CONFIG_ITEM_STANDBY_TIME);
        val standbyTime = if(standbyTimeRaw === null) null else standbyTimeRaw.clipStandbyTime?.value;
        val temperatureOversampling = configuration.getEnumerator(CONFIG_ITEM_TEMPERATURE_OVERSAMPLING)?.oversamplingConstant;
        val pressureOversampling = configuration.getEnumerator(CONFIG_ITEM_PRESSURE_OVERSAMPLING)?.oversamplingConstant;
        val humidityOversampling = configuration.getEnumerator(CONFIG_ITEM_HUMIDITY_OVERSAMPLING)?.oversamplingConstant;
        
        codeFragmentProvider.create('''
			Retcode_T exception = NO_EXCEPTION;
			exception = BSP_BME280_Connect(COMMONGATEWAY_BME280_ID);
			«generateExceptionHandler(null, "exception")»
			return exception;
		''').setPreamble('''
			int8_t bme280_Write(uint8_t address, uint8_t reg, uint8_t * data, uint16_t len)
			{
			    Retcode_T retcode = I2CTransceiver_Write(&i2cTransceiverStruct, address, reg, data, len);
			    if (RETCODE_OK == retcode)
			    {
			        return BME280_OK;
			    }
			    else
			    {
			        return BME280_E_COMM_FAIL;
			    }
			}
			
			int8_t bme280_Read(uint8_t address, uint8_t reg, uint8_t * data, uint16_t len)
			{
			    Retcode_T retcode = I2CTransceiver_Read(&i2cTransceiverStruct, address, reg, data, len);
			    if (RETCODE_OK == retcode)
			    {
			        return BME280_OK;
			    }
			    else
			    {
			        return BME280_E_COMM_FAIL;
			    }
			}
			struct bme280_dev bme280Struct = {
				.read = bme280_Read,
				.write = bme280_Write,
				.delay_ms = BSP_Board_Delay,
				.intf = BME280_I2C_INTF,
				.dev_id = COMMONGATEWAY_BME280_I2CADDRESS,
				.settings = {
					«IF pressureOversampling !== null»
					.osr_p = «pressureOversampling»,
					«ENDIF»
					«IF humidityOversampling !== null»
					.osr_h = «humidityOversampling»,
					«ENDIF»
					«IF temperatureOversampling !== null»
					.osr_t = «temperatureOversampling»,
					«ENDIF»
					«IF standbyTime !== null»
					.standby_time = «standbyTime»,
					«ENDIF»
					.filter = BME280_FILTER_COEFF_16,
				},
			};
		''')
		.addHeader("BSP_CommonGateway.h", false)
		.addHeader("BCDS_BSP_BME280.h", false)
		.addHeader("bme280.h", false)
		.addHeader("bme280_defs.h", false)
		.addHeader("BCDS_BSP_Board.h", false)
		.addHeader("PlatformCGW.h", false)
    }
    
    protected def String getOversamplingConstant(Singleton value) {
        return switch(value?.name) {
            case 'OVERSAMPLE_1X':  'BME280_OVERSAMPLING_1X'
            case 'OVERSAMPLE_2X':  'BME280_OVERSAMPLING_2X'
            case 'OVERSAMPLE_4X':  'BME280_OVERSAMPLING_4X'
            case 'OVERSAMPLE_8X':  'BME280_OVERSAMPLING_8X'
            case 'OVERSAMPLE_16X': 'BME280_OVERSAMPLING_16X'
            default: null
        }
    }
    
    override generateEnable() {
        val powerMode = if(configuration.getEnumerator(CONFIG_ITEM_POWER_MODE)?.name == 'Forced') 'BME280_FORCED_MODE' else 'BME280_NORMAL_MODE';
        
		return codeFragmentProvider.create('''
			Retcode_T exception = NO_EXCEPTION;
			exception = BSP_BME280_Enable(COMMONGATEWAY_BME280_ID);
			«generateExceptionHandler(null, "exception")»
			if (BME280_OK != bme280_init(&bme280Struct)) {
				exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
			}
			«generateExceptionHandler(null, "exception")»
			if (BME280_OK != bme280_set_sensor_settings(BME280_ALL_SETTINGS_SEL, &bme280Struct)) {
				exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
			}
			«generateExceptionHandler(null, "exception")»
			if(BME280_OK != bme280_set_sensor_mode(«powerMode», &bme280Struct)) {
				exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
			}
			«generateExceptionHandler(null, "exception")»
			BSP_Board_Delay(100);
			return exception;
		''')
		.setPreamble('''
			Retcode_T SensorEnvironmentRead(EnvironmentData_t* data) {
				struct bme280_data result;
				if(0 != bme280_get_sensor_data(BME280_ALL, &result, &bme280Struct)) {
					return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
				}
				data->humidity = result.humidity;
				data->pressure = result.pressure;
				data->temperature = result.temperature;
				return RETCODE_OK;
			}
		''').addHeader("cgwTypes.h", false);
	}
    
	override generateAccessPreparationFor(ModalityAccessPreparation accessPreparation) {
		return codeFragmentProvider.create('''
			EnvironmentData_t «accessPreparation.dataVariable»;
			exception = SensorEnvironmentRead(&«accessPreparation.dataVariable»);
			«generateExceptionHandler(component, 'exception')»
		''').addHeader("cgwTypes.h", false);
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
            case 'humidity': codeFragmentProvider.create('''«dataVariable».humidity''')
        }
    }
    
    /**
     * Translates an arbitrary standby time in milliseconds to a fixed, supported value.
     */
    static def Pair<Double, String> clipStandbyTime(long standbyTime) {
        val Map<Double, String> supportedValuesInMs = #{1.0 -> "1", 10.0 -> "10", 20.0 -> "20", 62.5 -> "62_5", 125.0 -> "125", 250.0 -> "250", 500.0 -> "500", 1000.0 -> "1000"};
        val nearestStandbyTime = supportedValuesInMs.entrySet.minBy[x| Math.abs(x.key - standbyTime)];
        val constantName = '''BME280_STANDBY_TIME_«nearestStandbyTime.value»_MS''';
        return nearestStandbyTime.key -> constantName;
    }
    
}
