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
		val radioApn = StaticValueInferrer.infer(radioSetup.getConfigurationItemValue("apn"), [])?.castOrNull(String);
		val radioUsername = StaticValueInferrer.infer(radioSetup.getConfigurationItemValue("username"), [])?.castOrNull(String);
		val radioPassword = StaticValueInferrer.infer(radioSetup.getConfigurationItemValue("password"), [])?.castOrNull(String);
		
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
			static uint32_t iccidLen = sizeof(iccid);
			
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
			
			
			static Retcode_T Http_WaitEvent(CellularHttp_ContentType_T command, uint32_t timeout)
			{
				HttpResult_T result;
				Retcode_T retcode = RETCODE_OK;
			
				if (pdFALSE != xQueueReceive(httpEvent, &result,timeout) )
				{
					if (command==result.command)
					{
						if(result.result == CELLULARHTTP_RESULT_SUCCESS) {
							retcode = RETCODE_OK;
						}
						else {
							retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
						}
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
		//.addHeader("BCDS_CellularInterface.h", true)
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
		val contentType = StaticValueInferrer.infer(signalInstance.getArgumentValue("contentType"), [])?.castOrNull(SumTypeRepr);
		val url = new URL(configuration.getString('endpointBase'));
		val port = if(url.port < 0) 80 else url.port;
		
		codeFragmentProvider.create('''
			Retcode_T exception = RETCODE_OK;
			
			CellularHttp_Data_T data = {
				.BufferLength = «valueVariableName»->length,
				.Buffer = «valueVariableName»->data,
			};
			
			CellularHttp_Request_T request = {
				.Method = CELLULARHTTP_METHOD_POST,
				.Server = "«url.host»",
				.Path = «signalInstance.getArgumentValue("endpoint").code»,
				.Port = «port»,
				.IsSecure = false,
				.ContentType = CELLULARHTTP_CONTENTTYPE_APP_«contentType?.name?.toUpperCase»,
				.Data = &data,
			};
			
			exception = CellularHttp_SendRequest(&request);
			
			if (exception == RETCODE_OK)
			{
				exception = Http_WaitEvent(CELLULARHTTP_METHOD_POST,120000);
			}
			
			return exception;
		''')
	}
	
	def translateContentType(SumTypeRepr contentType) {
		switch contentType?.name {
			case "Json":  "CELLULARHTTP_CONTENTTYPE_APP_JSON"
			case "Xml":   "CELLULARHTTP_CONTENTTYPE_APP_XML"
			case "Octet": "CELLULARHTTP_CONTENTTYPE_APP_OCTET"
			case "Text":  "CELLULARHTTP_CONTENTTYPE_RAW_TEXT"
		}
	}
	
	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		return codeFragmentProvider.create('''''')
	}
}