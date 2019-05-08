package org.eclipse.mita.platform.cgw.connectivity

import com.google.inject.Inject
import java.net.URL
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer.SumTypeRepr

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import static extension org.eclipse.mita.program.model.ModelUtils.getArgumentValue

class RestClientGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	protected extension GeneratorUtils generatorUtils
	
	@Inject
	protected extension StatementGenerator
	
	override generateSetup() {
		val radioSetup = configuration.getExpression("transport")?.castOrNull(ElementReferenceExpression)?.reference?.castOrNull(SystemResourceSetup);
		val radioStandard = StaticValueInferrer.infer(radioSetup.getConfigurationItemValue("radioStandard"), [])?.castOrNull(SumTypeRepr);
		
		return codeFragmentProvider.create('''
			Retcode_T exception = NO_EXCEPTION;

			
			powerOnDone = xSemaphoreCreateBinary();
			registerDone = xSemaphoreCreateBinary();
			dataActivated = xSemaphoreCreateBinary();
			if(dataActivated == NULL) {
				exception = RETCODE_FAILURE;
			}
			«generateLoggingExceptionHandler("HttpRestClient", "Semaphore creation")»

			xSemaphoreTake(powerOnDone, 0);
			xSemaphoreTake(registerDone, 0);
			xSemaphoreTake(dataActivated, 0);
			
			
			exception = Cellular_Initialize(HandleStateChanged);
			«generateLoggingExceptionHandler("HttpRestClient", "Cellular Initialize")»

			
			Cellular_PowerUpParameters_T powerUpParam;
			powerUpParam.SimPin = NULL;
			exception = Cellular_PowerOn(&powerUpParam);
			«generateLoggingExceptionHandler("HttpRestClient", "Cellular Power on")»


			uint32_t iccidLen = sizeof(iccid);
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
		''')
		.setPreamble('''
			static void ReceiveData(void* param, uint32_t len);
			
			static void OnDataReady(CellularSocket_Handle_T socket, uint32_t numBytesAvailable);
			
			static Retcode_T ActivateDataContext(void* param, uint32_t len);
			
			static void HandleStateChanged(Cellular_State_T oldState, Cellular_State_T newState, void* param, uint32_t len);
			
			static const Cellular_DataContext_T* DataContext;
			static CellularSocket_Handle_T Socket;
			static uint32_t BytesReceived = 0;
			extern CmdProcessor_T Mita_EventQueue;
			
			static QueueHandle_t httpEvent;
			
			static char iccid[CELLULAR_ICCID_MAX_LENGTH];
			
			static SemaphoreHandle_t powerOnDone, registerDone, dataActivated;
			
			static void ReceiveData(void* param, uint32_t len)
			{
				BCDS_UNUSED(param);
				BCDS_UNUSED(len);
			
				Retcode_T retcode = RETCODE_OK;
			
				uint8_t buffer[BytesReceived];
				uint32_t bytesReceived = 0;
				Cellular_IpAddress_T ip = { 0 };
				uint16_t port = 0;
			
				if (RETCODE_OK == retcode)
				{
					retcode = CellularSocket_Receive(Socket, buffer, sizeof(buffer), &bytesReceived);
				}
			
				if (RETCODE_OK == retcode)
				{
					LOG_DEBUG("Received data from %d.%d.%d.%d:%d | %.*s",
							(int ) ip.Address.IPv4[3],
							(int ) ip.Address.IPv4[2],
							(int ) ip.Address.IPv4[1],
							(int ) ip.Address.IPv4[0],
							(int ) port,
							(int ) bytesReceived,
							(char* ) buffer);
				}
			
				if (RETCODE_OK != retcode)
				{
					LOG_ERROR("Error during receiving data from socket (0x%08x)!", retcode);
					Retcode_RaiseError(retcode);
				}
			}
			
			static void OnDataReady(CellularSocket_Handle_T socket, uint32_t numBytesAvailable)
			{
				LOG_DEBUG("Socket data ready (id=%d, num=%d).", (int ) socket, (int ) numBytesAvailable);
				Retcode_T retcode = RETCODE_OK;
				BytesReceived = numBytesAvailable;
				retcode = CmdProcessor_Enqueue(&Mita_EventQueue, ReceiveData, NULL, 0);
			
				if (RETCODE_OK != retcode)
				{
					LOG_ERROR("Error during data-ready handling (0x%08x)!", retcode);
					Retcode_RaiseError(retcode);
				}
			}
			
			struct HttpResult_S
			{
				uint32_t command;
				uint32_t result;
			};
			typedef struct HttpResult_S HttpResult_T;
			
			static void HttpEventCallback(uint32_t command, uint32_t resultCode);
			
			static void HttpEventCallback(uint32_t command, uint32_t resultCode)
			{
				HttpResult_T httpResult;
				Retcode_T retcode;
			
				if (httpEvent!=NULL)
				{
					httpResult.command = command;
					httpResult.result = resultCode;
					if (pdFAIL == xQueueSend(httpEvent,&httpResult,0))
					{
						retcode = RETCODE(RETCODE_SEVERITY_ERROR,RETCODE_QUEUE_ERROR);
					}
				}
				else
				{
					retcode = RETCODE(RETCODE_SEVERITY_FATAL, RETCODE_NULL_POINTER);
				}
				if (retcode!= RETCODE_OK)
				{
					Retcode_RaiseError(retcode);
				}
			
			}
			
			
			static Retcode_T Http_WaitEvent(uint32_t command, uint32_t timeout)
			{
				HttpResult_T result;
				Retcode_T retcode = RETCODE_OK;
			
				if (pdFALSE != xQueueReceive(httpEvent, &result,timeout) )
				{
					if ((command==result.command) && (result.result == 1))
					{
						retcode = RETCODE_OK;
					}
					else
					{
						retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
					}
				}
				else
				{
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_TIMEOUT);
				}
				return retcode;
			}
			
			
			uint8_t httpBuffer[1024];
			
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
				ctxParam.ApnSettings.ApnName =  «IF configuration.getString("apn") !== null»"«configuration.getString("apn")»"«ELSE»NULL«ENDIF»;
				ctxParam.ApnSettings.AuthMethod = CELLULAR_APNAUTHMETHOD_NONE;
				ctxParam.ApnSettings.Username = «IF configuration.getString("username") !== null»"«configuration.getString("username")»"«ELSE»NULL«ENDIF»;
				ctxParam.ApnSettings.Password = «IF configuration.getString("password") !== null»"«configuration.getString("password")»"«ELSE»NULL«ENDIF»;
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
		//.addHeader("BCDS_CellularInterface.h", true)
		.addHeader("BCDS_Cellular.h", true)
		.addHeader("BCDS_CellularSocketService.h", true)
		.addHeader("BCDS_CellularDnsService.h", true)
		.addHeader("BCDS_CellularConfig.h", true)
		.addHeader("inttypes.h", true)
		
	}
	
	override generateEnable() {
		return codeFragmentProvider.create('''
			Retcode_T exception = NO_EXCEPTION;
			if(xSemaphoreTake(powerOnDone, 10000) == pdFALSE) {
				exception = RETCODE_FAILURE;
			}
			«generateLoggingExceptionHandler("HttpRestClient", "finish power on")»
			exception = Register(NULL, 0);
			«generateLoggingExceptionHandler("HttpRestClient", "Register")»

			if(xSemaphoreTake(registerDone, 600000) == pdFALSE) {
				exception = RETCODE_FAILURE;
			}
			«generateLoggingExceptionHandler("HttpRestClient", "finish registering")»
			exception = ActivateDataContext(NULL, 0);
			«generateLoggingExceptionHandler("HttpRestClient", "activate data context")»
			
			if(xSemaphoreTake(dataActivated, 120000) == pdFALSE) {
				exception = RETCODE_FAILURE;
			}
			«generateLoggingExceptionHandler("HttpRestClient", "finish data context activation")»
			httpEvent = xQueueCreate(1, sizeof(HttpResult_T));
			CellularHttp_Initialize(HttpEventCallback);
			
			return exception;
		''')
	}
	
	override generateSignalInstanceSetter(SignalInstance signalInstance, String valueVariableName) {
		val writeMethod = StaticValueInferrer.infer(signalInstance.getArgumentValue("writeMethod"), [])?.castOrNull(SumTypeRepr);
		val url = new URL(configuration.getString('endpointBase'));
		val port = if(url.port < 0) 80 else url.port;
		
		codeFragmentProvider.create('''
			char buf[«valueVariableName»->length + 1];
			memcpy(buf, «valueVariableName»->data, «valueVariableName»->length);
			buf[«valueVariableName»->length] = 0;
			Retcode_T exception = CellularHttp_Post("«url.host»", «signalInstance.getArgumentValue("endpoint").code», «port», buf, false);
			
			if (exception == RETCODE_OK)
			{
				exception = Http_WaitEvent(5,120000);
			}
			
			return exception;
		''')
	}
	
	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		return codeFragmentProvider.create('''''')
	}
}