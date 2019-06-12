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
		
		return codeFragmentProvider.create('''''')
		.setPreamble('''
			static void ReceiveData(void* param, uint32_t len);
			
			static void OnDataReady(CellularSocket_Handle_T socket, uint32_t numBytesAvailable);
			
			extern CmdProcessor_T Mita_EventQueue;
			
			static QueueHandle_t httpEvent;
			static CellularSocket_Handle_T Socket;
			static uint32_t BytesReceived = 0;
			
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
				.ContentType = «translateContentType(contentType)»,
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
		return switch contentType?.name {
			case "Json":   "CELLULARHTTP_CONTENTTYPE_APP_JSON"
			case "Xml":    "CELLULARHTTP_CONTENTTYPE_APP_XML"
			case "Octet":  "CELLULARHTTP_CONTENTTYPE_APP_OCTET"
			case "Text":   "CELLULARHTTP_CONTENTTYPE_TEXT_PLAIN"
			case "WwwUrl": "CELLULARHTTP_CONTENTTYPE_APP_X_WWW_URL"
			case "Multipart": "CELLULARHTTP_CONTENTTYPE_MULTIPLART"
			case null: null
		}
	}
	
	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		return codeFragmentProvider.create('''''')
	}
}