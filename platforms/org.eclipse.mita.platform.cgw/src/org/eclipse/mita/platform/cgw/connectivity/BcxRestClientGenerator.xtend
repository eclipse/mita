package org.eclipse.mita.platform.cgw.connectivity

import java.net.URL
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer.SumTypeRepr

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import static extension org.eclipse.mita.program.model.ModelUtils.getArgumentValue

class BcxRestClientGenerator extends RestClientGenerator {
	override generateSignalInstanceSetter(SignalInstance signalInstance, String valueVariableName) {
		val port = 80;
		
		codeFragmentProvider.create('''
			Retcode_T exception = RETCODE_OK;
			
			CellularHttp_Data_T data = {
				.BufferLength = «valueVariableName»->length,
				.Buffer = «valueVariableName»->data,
			};
			
			uint16_t bufSize = sizeof("/bc/x/api/px/sensgate/") + iccidLen + 1;
			char pathBuf[bufSize];
			memset(pathBuf, 0, bufSize*sizeof(char));
			int neededChars = snprintf(pathBuf, bufSize, "/bc/x/api/px/sensgate/%.*s", iccidLen, iccid);
			if(neededChars >= bufSize) {
				return EXCEPTION_STRINGFORMATEXCEPTION;
			}
			
			CellularHttp_Request_T request = {
				.Method = CELLULARHTTP_METHOD_POST,
				.Server = "connect.bosch-iot-suite.com",
				.Path = pathBuf,
				.Port = «port»,
				.IsSecure = false,
				.ContentType = CELLULARHTTP_CONTENTTYPE_APP_JSON,
				.Data = &data,
			};
			
			exception = CellularHttp_SendRequest(&request);
			
			if (exception == RETCODE_OK)
			{
				exception = Http_WaitEvent(CELLULARHTTP_METHOD_POST,120000);
			}
			
			return exception;
		''').addHeader("MitaExceptions.h", false)
	}
}