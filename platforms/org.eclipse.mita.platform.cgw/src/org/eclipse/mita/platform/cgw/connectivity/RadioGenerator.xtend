package org.eclipse.mita.platform.cgw.connectivity

import com.google.inject.Inject
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer.SumTypeRepr

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import org.eclipse.mita.program.generator.CodeFragment.IncludePath

class RadioGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	protected extension GeneratorUtils generatorUtils
	
	@Inject
	protected extension StatementGenerator
	
	override generateSetup() {
		val radioStandard = StaticValueInferrer.infer(setup.getConfigurationItemValue("radioStandard"), [])?.castOrNull(SumTypeRepr);
		val radioApn = configuration.getString("apn");
		val radioUsername = configuration.getString("username");
		val radioPassword = configuration.getString("password");
		
		
		return codeFragmentProvider.create('''
			Retcode_T exception = NO_EXCEPTION;
			
			powerOnDone = xSemaphoreCreateBinary();
			registerDone = xSemaphoreCreateBinary();
			dataActivated = xSemaphoreCreateBinary();
			if(dataActivated == NULL) {
				exception = RETCODE_FAILURE;
			}
			«generateLoggingExceptionHandler("Radio", "Semaphore creation")»

			xSemaphoreTake(powerOnDone, 0);
			xSemaphoreTake(registerDone, 0);
			xSemaphoreTake(dataActivated, 0);
			
			
			exception = Cellular_Initialize(HandleStateChanged);
			«generateLoggingExceptionHandler("Radio", "Cellular Initialize")»

			
			Cellular_PowerUpParameters_T powerUpParam;
			powerUpParam.SimPin = NULL;
			exception = Cellular_PowerOn(&powerUpParam);
			«generateLoggingExceptionHandler("Radio", "Cellular Power on")»

			exception = Cellular_QueryIccid(iccid, &iccidLen);
			
			if (RETCODE_OK != exception)
			{
				LOG_ERROR("Cellular failure: 0x%"PRIx32, exception);
				Retcode_RaiseError(exception);
			}
			else {
				LOG_DEBUG("SIM ICCID: %.*s", (int) iccidLen, iccid);
			}
			
			return exception;
		''').setPreamble('''
			static Retcode_T ActivateDataContext(void* param, uint32_t len);
			
			static void HandleStateChanged(Cellular_State_T oldState, Cellular_State_T newState, void* param, uint32_t len);
			
			static const Cellular_DataContext_T* DataContext;
			static SemaphoreHandle_t powerOnDone, registerDone, dataActivated;
			static char iccid[CELLULAR_ICCID_MAX_LENGTH];
			static uint32_t iccidLen = sizeof(iccid);
			
			static Retcode_T ActivateDataContext(void* param, uint32_t len)
			{
				BCDS_UNUSED(param);
				BCDS_UNUSED(len);
			
				Retcode_T retcode = RETCODE_OK;
			
				retcode = Cellular_ActivateDataContext(0, &DataContext);
			
				if (RETCODE_OK != retcode)
				{
					LOG_ERROR("Error during data-context activation (0x%08x)!", retcode);
					Retcode_RaiseError(retcode);
				}
				return retcode;
			}
			
			static Retcode_T Register(void* param, uint32_t len)
			{
				BCDS_UNUSED(param);
				BCDS_UNUSED(len);
				Retcode_T retcode = RETCODE_OK;
				Cellular_DataContextParameters_T ctxParam;
				ctxParam.Type = CELLULAR_DATACONTEXTTYPE_INTERNAL;
				ctxParam.ApnSettings.ApnName =  «IF radioApn !== null»"«radioApn»"«ELSE»NULL«ENDIF»;
				ctxParam.ApnSettings.AuthMethod = CELLULAR_APNAUTHMETHOD_NONE;
				ctxParam.ApnSettings.Username = «IF radioUsername !== null»"«radioUsername»"«ELSE»NULL«ENDIF»;
				ctxParam.ApnSettings.Password = «IF radioPassword !== null»"«radioPassword»"«ELSE»NULL«ENDIF»;
				retcode = Cellular_ConfigureDataContext(0, &ctxParam);
			
				if (RETCODE_OK == retcode)
				{ 
					Cellular_NetworkParameters_T networkParam;
«««										 possible values: CAT_M1, NB_IoT 
					networkParam.AcT = «IF radioStandard.name == "NB_IoT"»CELLULAR_RAT_LTE_CAT_NB1«ELSE»CELLULAR_RAT_LTE_CAT_M1«ENDIF»;
					retcode = Cellular_RegisterOnNetwork(&networkParam);
				}
			
				if (RETCODE_OK != retcode)
				{
					LOG_ERROR("Error during registering (0x%08x)!", retcode);
					Retcode_RaiseError(retcode);
				}
				return retcode;
			}
			
			static void HandleStateChanged(Cellular_State_T oldState, Cellular_State_T newState, void* param, uint32_t len)
			{
				BCDS_UNUSED(param);
				BCDS_UNUSED(len);
			
				Retcode_T retcode = RETCODE_OK;
				if (oldState == CELLULAR_STATE_REGISTERING && newState==CELLULAR_STATE_POWERON)
				{
					return;
				}
			
				LOG_INFO("State changed; old=%d, new=%d", oldState, newState);
			
				switch (newState)
				{
				case CELLULAR_STATE_POWERON:
					if(xSemaphoreGive(powerOnDone) == pdFALSE) {
						retcode = RETCODE_FAILURE;
					}
					break;
				case CELLULAR_STATE_REGISTERED:
					if(xSemaphoreGive(registerDone) == pdFALSE) {
						retcode = RETCODE_FAILURE;
					}
					break;
				case CELLULAR_STATE_DATAACTIVE:
					if(xSemaphoreGive(dataActivated) == pdFALSE) {
						retcode = RETCODE_FAILURE;
					}
					break;
				default:
					break;
				}
			
				if (RETCODE_OK != retcode)
				{
					LOG_ERROR("Error during state-handling (0x%08x)!", retcode);
					Retcode_RaiseError(retcode);
				}
			}
		''')
		.addHeader("FreeRTOS.h", true, IncludePath.HIGH_PRIORITY)
		.addHeader("semphr.h", true)
		.addHeader("queue.h", true)
		.addHeader("BCDS_Basics.h", true)
		.addHeader("BCDS_Retcode.h", true)
		.addHeader("BCDS_Logging.h", true)
		.addHeader("BCDS_MCU_UART.h", true)
		.addHeader("BCDS_CmdProcessor.h", true)
		.addHeader("BCDS_Cellular.h", true)
		.addHeader("BCDS_CellularSocketService.h", true)
		.addHeader("BCDS_CellularDnsService.h", true)
		.addHeader("BCDS_CellularConfig.h", true)
		.addHeader("inttypes.h", true)
		.addHeader("BCDS_CellularHttpService.h", false)
	}
	
	override generateEnable() {
		return codeFragmentProvider.create('''
			Retcode_T exception = NO_EXCEPTION;
			if(xSemaphoreTake(powerOnDone, 10000) == pdFALSE) {
				exception = RETCODE_FAILURE;
			}
			«generateLoggingExceptionHandler("Radio", "finish power on")»
			exception = Register(NULL, 0);
			«generateLoggingExceptionHandler("Radio", "Register")»

			if(xSemaphoreTake(registerDone, 600000) == pdFALSE) {
				exception = RETCODE_FAILURE;
			}
			«generateLoggingExceptionHandler("Radio", "finish registering")»
			exception = ActivateDataContext(NULL, 0);
			«generateLoggingExceptionHandler("Radio", "activate data context")»
			
			if(xSemaphoreTake(dataActivated, 120000) == pdFALSE) {
				exception = RETCODE_FAILURE;
			}
			«generateLoggingExceptionHandler("Radio", "finish data context activation")»
			return exception;
		''')
	}
	
}