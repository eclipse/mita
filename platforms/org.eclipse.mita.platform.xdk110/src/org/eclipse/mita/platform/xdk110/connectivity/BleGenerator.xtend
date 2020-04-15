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
import java.nio.ByteBuffer
import java.util.List
import java.util.regex.Pattern
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.TypeGenerator
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils

class BleGenerator extends AbstractSystemResourceGenerator {	
	@Inject
	protected extension GeneratorUtils
	
	@Inject
	protected TypeGenerator typeGenerator
	
	public static val MAC_ADDRESS_REGEX = "^([Ff][Cc]:[Dd]6:[Bb][Dd]:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2})|([Ff][Cc]-[Dd]6-[Bb][Dd]-[0-9A-Fa-f]{2}-[0-9A-Fa-f]{2}-[0-9A-Fa-f]{2})$";
	public static val MAC_ADDRESS_PATTERN = Pattern.compile(MAC_ADDRESS_REGEX);
	
	override generateSetup() {
		val baseName = (setup ?: component).baseName;
		
		val deviceName = configuration.getString('deviceName') ?: baseName;
		val serviceUid = configuration.getLong('serviceUID') ?: baseName.hashCode as long;
		val macAddressStr = configuration.getString('macAddress');
		var macAdressConfigured = false;
		val macAddress = if(macAddressStr !== null) {
			val macAddressMatcher = MAC_ADDRESS_PATTERN.matcher(macAddressStr);
			macAdressConfigured = macAddressMatcher.matches;
			if(macAdressConfigured) {
				macAddressStr.replaceAll('[:-]', '').toUpperCase;		
			}
		}
		
		val macAdressConfiguredFinal = macAdressConfigured;
		
		codeFragmentProvider.create('''
			Retcode_T retcode = RETCODE_OK;
			BleEventSignal = xSemaphoreCreateBinary();
			if (NULL == BleEventSignal)
			{
				retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
			}
			if (RETCODE_OK == retcode)
			{
			    BleSendCompleteSignal = xSemaphoreCreateBinary();
			    if (NULL == BleSendCompleteSignal)
			    {
			        retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
			        vSemaphoreDelete(BleEventSignal);
			    }
			}  
			if (RETCODE_OK == retcode)
			{
			    BleSendGuardMutex = xSemaphoreCreateMutex();
			    if (NULL == BleSendGuardMutex)
			    {
			        retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_OUT_OF_RESOURCES);
			        vSemaphoreDelete(BleEventSignal);
			        vSemaphoreDelete(BleSendCompleteSignal);
			    }
			}
			if (RETCODE_OK == retcode)
			{
			    retcode =  BlePeripheral_Initialize(«baseName»_OnEvent, «baseName»_ServiceRegistry);
			}
			if (RETCODE_OK == retcode)
			{
			    retcode = BlePeripheral_SetDeviceName((uint8_t*) _BLE_DEVICE_NAME);
			}
			if (RETCODE_OK == retcode)
			{
				«IF macAdressConfiguredFinal»
				// macAddress = «macAddressStr»
				uint64_t macAddress = 0x«macAddress»ll;
				retcode = BlePeripheral_SetMacAddress(macAddress);
				«ENDIF»
			}
			return retcode;

		''')
		.addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
		.addHeader('BCDS_Retcode.h', true, IncludePath.VERY_HIGH_PRIORITY)
		.addHeader("BCDS_BlePeripheral.h", true, IncludePath.HIGH_PRIORITY)
		.addHeader("attserver.h", true)
		.addHeader("FreeRTOS.h", true, IncludePath.HIGH_PRIORITY)
		.addHeader("task.h", true)
		.addHeader("semphr.h", true)
		.addHeader("stdio.h", true)
		.addHeader("XdkCommonInfo.h", true)
		.addHeader("string.h", true)
		.addHeader("stdlib.h", true)
		.setPreamble('''
		#define _BLE_DEVICE_NAME "«deviceName»"
		#define BLE_EVENT_SYNC_TIMEOUT                  UINT32_C(1000)
		static bool BleIsConnected = false;
		/**< Handle for BLE peripheral event signal synchronization */
		static SemaphoreHandle_t BleEventSignal = (SemaphoreHandle_t) NULL;
		/**< Handle for BLE data send complete signal synchronization */
		static SemaphoreHandle_t BleSendCompleteSignal = (SemaphoreHandle_t) NULL;
		/**< Handle for BLE data send Mutex guard */
		static SemaphoreHandle_t BleSendGuardMutex = (SemaphoreHandle_t) NULL;
		/**< BLE peripheral event */
		static BlePeripheral_Event_T BleEvent = BLE_PERIPHERAL_EVENT_MAX;
		/**< BLE send status */
		static Retcode_T BleSendStatus;
		
		/* «baseName» service */
		static uint8_t «baseName»ServiceUid[ATTPDU_SIZEOF_128_BIT_UUID] = { 0x66, 0x9A, 0x0C, 0x20, 0x00, 0x08, 0xF8, 0x82, 0xE4, 0x11, 0x66, 0x71, «FOR i : ByteBuffer.allocate(8).putLong(serviceUid).array() SEPARATOR ', '»0x«Integer.toHexString(i.bitwiseAnd(0xFF)).toUpperCase»«ENDFOR» };
		static AttServiceAttribute «baseName»Service;
		
		enum «baseName»_E {
		«FOR signalInstance : setup?.signalInstances»
			«baseName»_«signalInstance.name»,
		«ENDFOR»
		};
		
		«FOR signalInstance : setup?.signalInstances»
		/* «signalInstance.name» characteristic */
		static Att16BitCharacteristicAttribute «baseName»«signalInstance.name.toFirstUpper»CharacteristicAttribute;
		static uint8_t «baseName»«signalInstance.name.toFirstUpper»UuidValue[ATTPDU_SIZEOF_128_BIT_UUID] = { «signalInstance.characteristicUuid» };
		static AttUuid «baseName»«signalInstance.name.toFirstUpper»Uuid;
		//signalInstance has type A -> siginst<int32>, we need to extract int32 --> args[2].args[1] 
		static «typeGenerator.code(setup, ((BaseUtils.getType(signalInstance) as TypeConstructorType).typeArguments.get(2) as TypeConstructorType).typeArguments.get(1))» «baseName»«signalInstance.name.toFirstUpper»Value;
		static AttAttribute «baseName»«signalInstance.name.toFirstUpper»Attribute;
		«ENDFOR»

		«setup.buildServiceCallback(eventHandler)»
		«setup.buildSetupCharacteristic»
		«setup.buildReadWriteCallback(eventHandler)»
		
		static Retcode_T «component.baseName»_SendData(uint8_t* dataToSend, uint8_t dataToSendLen, void * param, uint32_t timeout)
		{
			Retcode_T retcode = RETCODE_OK;
			if (pdTRUE == xSemaphoreTake(BleSendGuardMutex, pdMS_TO_TICKS(BLE_EVENT_SYNC_TIMEOUT)))
			{
				if (BleIsConnected == true)
				{
					BleSendStatus = RETCODE_OK;
					/* This is a dummy take. In case of any callback received
					 * after the previous timeout will be cleared here. */
					(void) xSemaphoreTake(BleSendCompleteSignal, pdMS_TO_TICKS(0));
					// tell the world via BLE
					«FOR signalInstance : setup?.signalInstances»
					if((enum «baseName»_E)param == «baseName»_«signalInstance.name»)
					{
						ATT_SERVER_SecureDatabaseAccess();
						AttStatus status = ATT_SERVER_WriteAttributeValue(
						    &«baseName»«signalInstance.name.toFirstUpper»Attribute,
						    dataToSend,
						    dataToSendLen
						);
						if (status == BLESTATUS_SUCCESS) /* send notification */
					 	{
					 		status = ATT_SERVER_SendNotification(&«baseName»«signalInstance.name.toFirstUpper»Attribute, 1);
					 		/* BLESTATUS_SUCCESS and BLESTATUS_PENDING are fine */
					 		if ((status == BLESTATUS_FAILED) || (status == BLESTATUS_INVALID_PARMS))
					 		{
					 		 	retcode = RETCODE(RETCODE_SEVERITY_ERROR, (Retcode_T ) RETCODE_SEND_NOTIFICATION_FAILED);
					 		}
					 	}
					 	else
					 	{
					 		if (BLESTATUS_SUCCESS != status)
					 		{
					 			retcode = RETCODE(RETCODE_SEVERITY_ERROR, (Retcode_T ) RETCODE_REWRITE_OF_ATT_FAILED);
					 		}
					 	}
					 	ATT_SERVER_ReleaseDatabaseAccess();
					 	if (pdTRUE != xSemaphoreTake(BleSendCompleteSignal, pdMS_TO_TICKS(timeout)))
					 	{
					 		retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_BLE_START_FAILED);
					 	}
					}
					
				    «ENDFOR»							
				}
				else
				{
				 	retcode = EXCEPTION_NODEVICECONNECTEDEXCEPTION;
			    }
						
				if (pdTRUE != xSemaphoreGive(BleSendGuardMutex))
				{
					/* This is fatal since the BleSendGuardMutex must be given as the same thread takes this */
				 	retcode = RETCODE(RETCODE_SEVERITY_FATAL, RETCODE_BLE_SEND_MUTEX_NOT_RELEASED);
				}
			}
			else
			{
				 retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_SEMAPHORE_ERROR);
			}
			return retcode;
		}
		''')
	}
	
	private static def getCharacteristicUuid(SignalInstance value) {
		val uuidRawValue = StaticValueInferrer.infer(ModelUtils.getArgumentValue(value, 'UUID'), [ ]);
		val uuid = if(uuidRawValue instanceof Integer) {
			uuidRawValue;
		} else {
			value.name.hashCode;
		}
		
		getUuidArrayCode(#[0x66, 0x9A, 0x0C, 0x20, 0x00, 0x08, 0xF8, 0x82, 0xE4, 0x11, 0x66, 0x71], uuid);
	}
	
	private static def getUuidArrayCode(List<Integer> header, Integer tail) {
		val buffer = ByteBuffer.allocate(4);
		buffer.putInt(tail);
		
		'''«FOR i : buffer.array().reverse() SEPARATOR ', '»0x«Integer.toHexString(i.bitwiseAnd(0xFF)).toUpperCase»«ENDFOR», «FOR i : header SEPARATOR ', '»0x«Integer.toHexString(i.bitwiseAnd(0xFF)).toUpperCase»«ENDFOR»'''
	}
	
	private def CodeFragment buildServiceCallback(SystemResourceSetup component, Iterable<EventHandlerDeclaration> declarations) {
		codeFragmentProvider.create('''
		static void «component.baseName»_ServiceCallback(AttServerCallbackParms *serverCallbackParams)
		{
			switch (serverCallbackParams->event)
				{
				case ATTEVT_SERVER_HVI_SENT:
				{
					if (ATTSTATUS_SUCCESS != serverCallbackParams->status)
					{
						Retcode_RaiseError(RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_DATA_SEND_FAIL));
					}
					if (pdTRUE != xSemaphoreGive(BleSendCompleteSignal))
					{
						/* This is fatal since the BleSendGuardMutex must be given as the same thread takes this */
						Retcode_RaiseError(RETCODE(RETCODE_SEVERITY_FATAL, RETCODE_BLE_SEND_MUTEX_NOT_RELEASED));
					}
					break;
				}
			
				default:
					break;
				}
		}
		
		''')
	}
	
	private def CodeFragment buildReadWriteCallback(SystemResourceSetup component, Iterable<EventHandlerDeclaration> eventHandler) {
		val baseName = component.baseName
		
		codeFragmentProvider.create('''
		static void «baseName»_OnEvent(BlePeripheral_Event_T event, void* data)
		{
		    BCDS_UNUSED(data);
		    BleEvent = event;
		
		    switch (event)
		    {
		    case BLE_PERIPHERAL_STARTED:
		        printf("BleEventCallBack : BLE powered ON successfully \r\n");
		        if (pdTRUE != xSemaphoreGive(BleEventSignal))
		        {
		            /* We would not expect this call to fail because we expect the application thread to wait for this semaphore */
		            Retcode_RaiseError(RETCODE(RETCODE_SEVERITY_WARNING, RETCODE_SEMAPHORE_ERROR));
		        }
		        break;
		    case BLE_PERIPHERAL_SERVICES_REGISTERED:
		        break;
		    case BLE_PERIPHERAL_SLEEP_SUCCEEDED:
		        printf("BleEventCallBack : BLE successfully entered into sleep mode \r\n");
		        break;
		    case BLE_PERIPHERAL_WAKEUP_SUCCEEDED:
		        printf("BleEventCallBack : Device Wake up succeeded \r\n");
		        if (pdTRUE != xSemaphoreGive(BleEventSignal))
		        {
		            /* We would not expect this call to fail because we expect the application thread to wait for this semaphore */
		            Retcode_RaiseError(RETCODE(RETCODE_SEVERITY_WARNING, RETCODE_SEMAPHORE_ERROR));
		        }
		        break;
		    case BLE_PERIPHERAL_CONNECTED:
		        printf("BleEventCallBack : Device connected \r\n");
		        BleIsConnected = true;
		        break;
		    case BLE_PERIPHERAL_DISCONNECTED:
		        printf("BleEventCallBack : Device Disconnected \r\n");
		        BleIsConnected = false;
		        break;
		    case BLE_PERIPHERAL_ERROR:
		        printf("BleEventCallBack : BLE Error Event \r\n");
		        break;
		    default:
		        Retcode_RaiseError(RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_BLE_INVALID_EVENT_RECEIVED));
		        break;
		    }
		}
		
		''')
		.addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
	}
	
	private def CodeFragment buildSetupCharacteristic(SystemResourceSetup component) {
		val baseName = component.baseName
		
		codeFragmentProvider.create('''
		static Retcode_T «baseName»_ServiceRegistry(void)
		{
			Retcode_T retcode = RETCODE_OK;
			// register service we'll connect our characteristics to
			ATT_SERVER_SecureDatabaseAccess();
			AttStatus registerStatus = ATT_SERVER_RegisterServiceAttribute(
				ATTPDU_SIZEOF_128_BIT_UUID,
				«baseName»ServiceUid,
				«baseName»_ServiceCallback,
				&«baseName»Service
			);
			ATT_SERVER_ReleaseDatabaseAccess();
			if(registerStatus != BLESTATUS_SUCCESS)
			{
				return registerStatus;
			}
			
			«FOR signalInstance : setup.signalInstances»
			// setup «signalInstance.name» characteristics
			«baseName»«signalInstance.name.toFirstUpper»Uuid.size = ATT_UUID_SIZE_128;
			«baseName»«signalInstance.name.toFirstUpper»Uuid.value.uuid128 = «baseName»«signalInstance.name.toFirstUpper»UuidValue;
			ATT_SERVER_SecureDatabaseAccess();
			registerStatus = ATT_SERVER_AddCharacteristic(
				ATTPROPERTY_READ | ATTPROPERTY_WRITE | ATTPROPERTY_NOTIFY,
				&«baseName»«signalInstance.name.toFirstUpper»CharacteristicAttribute,
				&«baseName»«signalInstance.name.toFirstUpper»Uuid,
				ATT_PERMISSIONS_ALLACCESS, 
				«signalInstance.contentLength»,
				(uint8_t *) &«baseName»«signalInstance.name.toFirstUpper»Value,
				FALSE,
				«signalInstance.contentLength»,
				&«baseName»Service,
				&«baseName»«signalInstance.name.toFirstUpper»Attribute
			);
			if(registerStatus != BLESTATUS_SUCCESS)
			{
				return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
			}
			ATT_SERVER_ReleaseDatabaseAccess();
			
			«ENDFOR»
			return (retcode);
		}

		''')
	}
	
	private def getContentLength(SignalInstance value) {
		val type = (BaseUtils.getType(value) as TypeConstructorType).typeArguments.tail.head;
		return switch(type?.name) {
			case 'bool': 1
			case 'int32': 4
			case 'uint32': 4
			default: null
		}
	}
	
	override generateEnable() {
		codeFragmentProvider.create('''
		Retcode_T retcode = RETCODE_OK;
		
		/* @todo - BLE in XDK is unstable for wakeup upon bootup.
		 * Added this delay for the same.
		 * This needs to be addressed in the HAL/BSP. */
		vTaskDelay(pdMS_TO_TICKS(1000));
		
		/* This is a dummy take. In case of any callback received
		 * after the previous timeout will be cleared here. */
		(void) xSemaphoreTake(BleEventSignal, pdMS_TO_TICKS(0));
		retcode = BlePeripheral_Start();
		if (RETCODE_OK == retcode)
		{
		    if (pdTRUE != xSemaphoreTake(BleEventSignal, pdMS_TO_TICKS(BLE_EVENT_SYNC_TIMEOUT)))
		    {
		        retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_BLE_START_FAILED);
		    }
		    else if (BleEvent != BLE_PERIPHERAL_STARTED)
		    {
		        retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_BLE_START_FAILED);
		    }
		    else
		    {
		        /* Do not disturb retcode */;
		    }
		}
		
		/* This is a dummy take. In case of any callback received
		 * after the previous timeout will be cleared here. */
		(void) xSemaphoreTake(BleEventSignal, pdMS_TO_TICKS(0));
		if (RETCODE_OK == retcode)
		{
		    retcode = BlePeripheral_Wakeup();
		}
		if (RETCODE_OK == retcode)
		{
		    if (pdTRUE != xSemaphoreTake(BleEventSignal, pdMS_TO_TICKS(BLE_EVENT_SYNC_TIMEOUT)))
		    {
		        retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_BLE_WAKEUP_FAILED);
		    }
		    else if (BleEvent != BLE_PERIPHERAL_WAKEUP_SUCCEEDED)
		    {
		        retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_BLE_WAKEUP_FAILED);
		    }
		    else
		    {
		        /* Do not disturb retcode */;
		    }
		}
		return retcode;
		''')
	}
	
	override generateSignalInstanceSetter(SignalInstance signalInstance, String resultName) {
		val retTypeModality = BaseUtils.getType(signalInstance) as TypeConstructorType;
		val retType = retTypeModality.typeArguments.tail.head;
		val baseName = setup.baseName
		
		codeFragmentProvider.create('''
		Retcode_T retcode = RETCODE_OK;
		if(«resultName» == NULL)
		{
			retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_NULL_POINTER);
		}
		else
		{
			memcpy(&«baseName»«signalInstance.name.toFirstUpper»Value, «resultName», sizeof(«typeGenerator.code(signalInstance, retType)»));
			retcode = «component.baseName»_SendData((uint8_t *) &«baseName»«signalInstance.name.toFirstUpper»Value, sizeof(«typeGenerator.code(signalInstance, retType)»), (void*)«baseName»_«signalInstance.name»,1000);
		}
		return retcode;
		''')
	}
	
	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		val retTypeModality = BaseUtils.getType(signalInstance) as TypeConstructorType;
		val retType = retTypeModality.typeArguments.tail.head;
		val baseName = setup.baseName
		
		codeFragmentProvider.create('''
		if(«resultName» == NULL)
		{
			return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_NULL_POINTER);
		}
		
		memcpy(«resultName», &«baseName»«signalInstance.name.toFirstUpper»Value, sizeof(«typeGenerator.code(signalInstance, retType)»));
		''')
		.addHeader('string.h', true)
	}
	
}