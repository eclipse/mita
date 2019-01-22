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
		val confirmation = StaticValueInferrer.infer(ModelUtils.getArgumentValue(signalInstance, "confirmation"), []);
		if(confirmation instanceof Enumerator) {
			val portNum = ModelUtils.getArgumentValue(signalInstance, "num");
			val sendName = "LoRa_Send" + confirmation.name;
			
			return codeFragmentProvider.create('''
				return «sendName»(«portNum.code», «valueVariableName»->data, «valueVariableName»->length);
			''')			
		}
		
	}
	
	
	
	
}