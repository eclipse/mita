/********************************************************************************
 * Copyright (c) 2019 Bosch Connected Devices and Solutions GmbH.
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
import java.util.List
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils

class LoraGenerator extends AbstractSystemResourceGenerator {
	@Inject extension 
	StatementGenerator statementGenerator;
	
	@Inject extension
	GeneratorUtils generatorUtils;
	
	override generateSetup() {
		codeFragmentProvider.create('''
	        Retcode_T exception = RETCODE_OK;
	        LoraJoinHandle = xSemaphoreCreateBinary();
	        if (NULL == LoraJoinHandle)
	        {
	            vSemaphoreDelete(LoraJoinHandle);
	            exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
	        }
	        else
	        {
	            LoRaJoinStatus = false;
	        }
	        return exception;
		''').setPreamble(
			'''
			#define JOIN_TIMEOUT 10000
			/**< Handle for LORA join operation  */
			static SemaphoreHandle_t LoraJoinHandle;
			/**< LoRa join status */
			static bool LoRaJoinStatus = false;
			
			/**
			 * @brief   LoRa Network Callback function used by the stack to communicate events to the application
			 *
			 * @param[in] flags Currently not used
			 *
			 * @param[in] eventInfo Hold the information about the event
			 *
			 */
			static void LoRaCallbackFunc(void *flags, LoRaMacEventInfo_T *eventInfo)
			{
			    BCDS_UNUSED(flags);
			    Retcode_T retcode = RETCODE_OK;
			    switch (eventInfo->event)
			    {
			        case LORA_NETWORK_JOIN_SUCCESS:
				        LoRaJoinStatus = true;
				        if (pdTRUE != xSemaphoreGive(LoraJoinHandle))
				        {
				            retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				        }
				        break;
			        case LORA_NETWORK_JOIN_TIMEOUT:
			        case LORA_NETWORK_JOIN_FAILURE:
				        LoRaJoinStatus = false;
				        printf("Lora Network join timeout/failure: %d \r\n", eventInfo->event);
				        if (pdTRUE != xSemaphoreGive(LoraJoinHandle))
				        {
				            retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
				        }
			        	break;
			        case LORA_NETWORK_RECEIVED_PACKET:
				        printf("Lora Network Received Packet \r\n");
			        	break;
			        case LORA_NETWORK_SEND_FAILED:
				        printf("Lora Network Send Failed \r\n");
				        break;
			        case LORA_NETWORK_RECEIVE_FAILED:
			        	printf("Lora Join Failed State \r\n");
			        	break;
			        default:
			        break;
			    }
			    if (RETCODE_OK != retcode)
			    {
			        Retcode_RaiseError(retcode);
			    }
			}
			«IF setup.signalInstances.exists[it.instanceOf.name == "cayenne"]»
			// required data structures for cayenne
			// translation CayennePayload_enum -> cayenne used buffer size in bytes
			static const uint8_t payloadSizes[] = {
				3, 3, 4, 4, 4, 3, 4, 3, 8, 4, 8, 11
			};
			// translation CayennePayload_enum -> CayenneLPPSerializer_DataType_T
			static const CayenneLPPSerializer_DataType_T cayenneDataTypes[] = {
				CAYENNE_LLP_SERIALIZER_DIGITAL_INPUT,
				CAYENNE_LLP_SERIALIZER_DIGITAL_OUTPUT,
				CAYENNE_LLP_SERIALIZER_ANALOG_INPUT,
				CAYENNE_LLP_SERIALIZER_ANALOG_OUTPUT,
				CAYENNE_LLP_SERIALIZER_ILLUMINANCE_SENSOR,
				CAYENNE_LLP_SERIALIZER_PRESENCE_SENSOR,
				CAYENNE_LLP_SERIALIZER_TEMPERATURE_SENSOR,
				CAYENNE_LLP_SERIALIZER_HUMIDITY_SENSOR,
				CAYENNE_LLP_SERIALIZER_ACCELEROMETER,
				CAYENNE_LLP_SERIALIZER_BAROMETER,
				CAYENNE_LLP_SERIALIZER_GYROMETER,
				CAYENNE_LLP_SERIALIZER_GPS_LOCATION
			};
			«ENDIF»
			'''
		)
		.addHeader("FreeRTOS.h", true, IncludePath.HIGH_PRIORITY)
		.addHeader("semphr.h", true)
		.addHeader("BCDS_LoRaDevice.h", true)
		
	}
	
	override generateEnable() {
	    val appEui = StaticValueInferrer.infer(configuration.getExpression("loraAppEui"), []);
		val appKey = StaticValueInferrer.infer(configuration.getExpression("loraAppKey"), []);
		val deviceEui = StaticValueInferrer.infer(configuration.getExpression("loraDeviceEui"), []);
		if(appEui instanceof List) {
			if(appKey instanceof List) {
				return codeFragmentProvider.create('''
					Retcode_T exception = RETCODE_OK;
					exception = LoRaDevice_Init(LoRaCallbackFunc, 868);
					«generateLoggingExceptionHandler("LoRa", "device init")»
					exception = LoRaDevice_SetRxWindow2(0, 869525000);
					«generateLoggingExceptionHandler("LoRa", "set rx window")»
					«IF deviceEui instanceof List»
					exception = LoRaDevice_SetDevEUI(devEUI);
					if(exception == NO_EXCEPTION)
					{
						uint64_t actualDevEUI;
						exception = LoRaDevice_GetDevEUI(&actualDevEUI);
						if(exception != NO_EXCEPTION) {
							printf("[ERROR, %s:%d] failed to set device eui LoRa\n", __FILE__, __LINE__);
						}
						printf("[INFO, %s:%d] set device eui LoRa succeeded: %llx\n", __FILE__, __LINE__, actualDevEUI);
					}
					else
					{
						printf("[ERROR, %s:%d] failed to set device eui LoRa\n", __FILE__, __LINE__);
						return exception;
					}
					«ELSE»
					uint64_t hwEui = 0;
					exception = LoRaDevice_GetHwEUI(&hwEui);
					«generateLoggingExceptionHandler("LoRa", "get hw eui")»
					exception = LoRaDevice_SetDevEUI(hwEui);
					«generateLoggingExceptionHandler("LoRa", "set dev eui")»
					«ENDIF»
					exception = LoRaDevice_SetAppEUI(0x«appEui.map[String.format("%02x", #[it])].join("")»);
					«generateLoggingExceptionHandler("LoRa", "set app eui")»
					exception = LoRaDevice_SetAppKey(appKey);
					«generateLoggingExceptionHandler("LoRa", "set app key")»

					exception = LoRaDevice_SetRadioCodingRate(codingRate);
					«generateLoggingExceptionHandler("LoRa", "set radio coding rate")»
					
					exception = LoRaDevice_SetADR(«configuration.getExpression("adaptiveDataRate").code»);
					«generateLoggingExceptionHandler("LoRa", "set adaptive data rate")»

					exception = LoRaDevice_SaveConfig();
					«generateLoggingExceptionHandler("LoRa", "save config")»
					
					exception = LoRa_Join();
					if(exception == NO_EXCEPTION)
					{
						printf("[INFO, %s:%d] joining network LoRa succeeded\n", __FILE__, __LINE__);
					}
					else
					{
						printf("[ERROR, %s:%d] failed to join network LoRa\n", __FILE__, __LINE__);
						Retcode_RaiseError(exception);
						return exception;
					}

					if (RETCODE_OK == exception)
					{
					    printf("LoRa_Enable: LoRa Join Success...\r\n");
					    do
					    {
					        exception = LoRa_SetDataRate(0);
					        if (RETCODE_OK == exception)
					        {
					            /*to avoid losing the first frame sent to the gateway: gateway duplicate error message */
					            exception = LoRa_SendUnconfirmed(UINT8_C(1), (void*) 'X', UINT16_C(1));
					        }
					        if (RETCODE_OK == exception)
					        {
					            // Set Data Rate to 3 (increase amount of data to send) and send the data via LoRa
					            exception = LoRa_SetDataRate(3);
					        }
					        if (RETCODE_OK != exception)
					        {
					            printf("LoRa enable: Sending first frame to gateway failed Retrying  ...\r\n");
					        }
					    } while (RETCODE_OK != exception);
					}
					«generateLoggingExceptionHandler("LoRa", "enable")»

					return exception;
				''').setPreamble('''
				const uint8_t appKey[16] = { «appKey.map[String.format("0x%02x", #[it])].join(", ")» };
				const char* codingRate = "4/5";
				«IF deviceEui instanceof List»
				const uint64_t devEUI = 0x«deviceEui.map[String.format("%02x", #[it])].join("")»;
				«ENDIF»
				
				static Retcode_T LoRa_Join(void)
				{
				    Retcode_T retcode = RETCODE_OK;
				
				    // This is a dummy semaphore take
				    (void)xSemaphoreTake(LoraJoinHandle, 0);
				    retcode = LoRaDevice_Join(LORA_JOIN_OTAA);
				    if (RETCODE_OK == retcode)
				    {
				        if ((pdTRUE != xSemaphoreTake(LoraJoinHandle, pdMS_TO_TICKS(JOIN_TIMEOUT)) || (false == LoRaJoinStatus)))
				        {
				            retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_LORA_JOIN_FAILED);
				        }
				    }
				    return (retcode);
				}
				
				static Retcode_T LoRa_SendUnconfirmed(uint8_t LoRaPort, uint8_t *dataBuffer, uint32_t dataBufferSize)
				{
				    Retcode_T retcode = RETCODE_OK;
				    if (NULL == dataBuffer)
				    {
				        return (RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_NULL_POINTER));
				    }
				    retcode = LoRaDevice_SendUnconfirmed(LoRaPort, dataBuffer, (uint16_t) dataBufferSize);
				    return (retcode);
				}
				
				static Retcode_T LoRa_SendConfirmed(uint8_t LoRaPort, uint8_t *dataBuffer, uint32_t dataBufferSize)
				{
				    Retcode_T retcode = RETCODE_OK;
				    if (NULL == dataBuffer)
				    {
				        return (RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_NULL_POINTER));
				    }
				    retcode = LoRaDevice_SendConfirmed(LoRaPort, dataBuffer, (uint16_t) dataBufferSize);
				    return (retcode);
				}
				''')
				.addHeader("FreeRTOS.h", true, IncludePath.HIGH_PRIORITY)
				.addHeader("semphr.h", true)
				.addHeader("BCDS_LoRaDevice.h", true)
				.addHeader("XdkCommonInfo.h", true)
			}
		}
		return codeFragmentProvider.create('''ERROR: expected value not array literal!''')
		
	}
	
	override generateSignalInstanceGetter(SignalInstance signalInstance, String valueVariableName) {
		return CodeFragment.EMPTY;
	}
	override generateSignalInstanceSetter(SignalInstance signalInstance, String valueVariableName) {
		val signal = signalInstance.instanceOf;
		val confirmation = StaticValueInferrer.infer(ModelUtils.getArgumentValue(signalInstance, "confirmation"), []);
		if(confirmation instanceof Enumerator) {
			val portNum = ModelUtils.getArgumentValue(signalInstance, "portNum");
			val sendName = "LoRa_Send" + confirmation.name;
			if(signal.name == "raw") {
				return codeFragmentProvider.create('''
					return «sendName»(«portNum.code», «valueVariableName»->data, «valueVariableName»->length);
				''')
			}
			else {
				/*
				 * #define TEMPERATURE_DATA_CH      0x01
				 * #define HUMIDITY_DATA_CH         0x02
				 * #define PRESSURE_DATA_CH         0x03
				 * #define ILLUMINANCE_DATA_CH      0x04
				 */
				/*
				 * #define DIGITAL_INPUT_SINGLE_PAYLOAD_SIZE           3U
				 * #define DIGITAL_OUTPUT_SINGLE_PAYLOAD_SIZE          3U
				 * #define ANALOG_INPUT_SINGLE_PAYLOAD_SIZE            4U
				 * #define ANALOG_OUTPUT_SINGLE_PAYLOAD_SIZE           4U
				 * #define ILLUMINANCE_SENSOR_SINGLE_PAYLOAD_SIZE      4U
				 * #define PRESENCE_SENSOR_SINGLE_PAYLOAD_SIZE         3U
				 * #define TEMPERATURE_SENSOR_SINGLE_PAYLOAD_SIZE      4U
				 * #define HUMIDITY_SENSOR_SINGLE_PAYLOAD_SIZE         3U
				 * #define ACCELEROMETER_SINGLE_PAYLOAD_SIZE           8U
				 * #define BAROMETER_SINGLE_PAYLOAD_SIZE               4U
				 * #define GYROMETER_SINGLE_PAYLOAD_SIZE               8U
				 * #define GPS_LOCATION_SINGLE_PAYLOAD_SIZE            11U
				 */
				return codeFragmentProvider.create('''
					Retcode_T exception = NO_EXCEPTION;
					CayenneLPPSerializer_Input_T cayenneLPPSerializerInput;
					CayenneLPPSerializer_Output_T cayenneLPPSerializerOutput;
					size_t bufferEntries = «valueVariableName»->length;
					size_t bufferSize = 0;
					for(size_t i = 0; i < bufferEntries; i++) {
						bufferSize += payloadSizes[«valueVariableName»->data[i].tag];
					}
					uint8_t dataBuffer[bufferSize];
					
					cayenneLPPSerializerOutput.BufferPointer = dataBuffer;
					for(size_t i = 0; i < bufferEntries; i++) {
						 cayenneLPPSerializerInput.DataType = cayenneDataTypes[«valueVariableName»->data[i].tag];
						 cayenneLPPSerializerInput.DataChannel = «valueVariableName»->data[i].tag; // todo actually use some kind of channel here?
						 switch(«valueVariableName»->data[i].tag) {
						 	case CayennePayload_DigitalInput_e:
						 		cayenneLPPSerializerInput.Data.DigitalInput.DigitalInputValue = «valueVariableName»->data[i].data.DigitalInput;
						 		break;
						 	case CayennePayload_DigitalOutput_e:
						 		cayenneLPPSerializerInput.Data.DigitalOutput.DigitalOutputValue = «valueVariableName»->data[i].data.DigitalOutput;
						 		break;
						 	case CayennePayload_AnalogInput_e:
						 		cayenneLPPSerializerInput.Data.AnalogInput.AnalogInputValue = «valueVariableName»->data[i].data.AnalogInput;
						 		break;
						 	case CayennePayload_AnalogOutput_e:
						 		cayenneLPPSerializerInput.Data.AnalogOutput.AnalogOutputValue = «valueVariableName»->data[i].data.AnalogOutput;
						 		break;
						 	case CayennePayload_IlluminanceSensor_e:
						 		cayenneLPPSerializerInput.Data.IlluminanceSensor.IlluminanceSensorValue = «valueVariableName»->data[i].data.IlluminanceSensor;
						 		break;
						 	case CayennePayload_PresenceSensor_e:
						 		cayenneLPPSerializerInput.Data.PresenceSensor.PresenceSensorValue = «valueVariableName»->data[i].data.PresenceSensor;
						 		break;
						 	case CayennePayload_TemperatureSensor_e:
						 		cayenneLPPSerializerInput.Data.TemperatureSensor.TemperatureSensorValue = «valueVariableName»->data[i].data.TemperatureSensor;
						 		break;
						 	case CayennePayload_HumiditySensor_e:
						 		cayenneLPPSerializerInput.Data.HumiditySensor.HumiditySensorValue = «valueVariableName»->data[i].data.HumiditySensor;
						 		break;
						 	case CayennePayload_Accelerometer_e:
						 		cayenneLPPSerializerInput.Data.Accelerometer.AccelerometerXValue = «valueVariableName»->data[i].data.Accelerometer._0;
						 		cayenneLPPSerializerInput.Data.Accelerometer.AccelerometerYValue = «valueVariableName»->data[i].data.Accelerometer._1;
						 		cayenneLPPSerializerInput.Data.Accelerometer.AccelerometerZValue = «valueVariableName»->data[i].data.Accelerometer._2;
						 		break;
						 	case CayennePayload_Barometer_e:
						 		cayenneLPPSerializerInput.Data.Barometer.BarometerValue = «valueVariableName»->data[i].data.Barometer;
						 		break;
						 	case CayennePayload_Gyrometer_e:
						 		cayenneLPPSerializerInput.Data.Gyrometer.GyrometerXValue = «valueVariableName»->data[i].data.Gyrometer._0;
						 		cayenneLPPSerializerInput.Data.Gyrometer.GyrometerYValue = «valueVariableName»->data[i].data.Gyrometer._1;
						 		cayenneLPPSerializerInput.Data.Gyrometer.GyrometerZValue = «valueVariableName»->data[i].data.Gyrometer._2;
						 		break;
						 	case CayennePayload_GpsLocation_e:
						 		cayenneLPPSerializerInput.Data.GPSLocation.Latitude = «valueVariableName»->data[i].data.GpsLocation.Latitude; 
						 		cayenneLPPSerializerInput.Data.GPSLocation.Longitude = «valueVariableName»->data[i].data.GpsLocation.Longitude; 
						 		cayenneLPPSerializerInput.Data.GPSLocation.Altitude = «valueVariableName»->data[i].data.GpsLocation.Altitude; 
						 		break;
						 }
						 exception = CayenneLPPSerializer_SingleInstance(&cayenneLPPSerializerInput, &cayenneLPPSerializerOutput);
						 cayenneLPPSerializerOutput.BufferPointer += cayenneLPPSerializerOutput.BufferFilledLength;
					}
					return «sendName»(«portNum.code», dataBuffer, bufferSize);
				''')
				.addHeader("xdk110Types.h", false)
				.addHeader("XDK_CayenneLPPSerializer.h", true)
			}
		}
		
	}
	
	
	
	
}