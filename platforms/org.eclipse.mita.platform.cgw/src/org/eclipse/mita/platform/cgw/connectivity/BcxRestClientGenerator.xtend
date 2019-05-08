package org.eclipse.mita.platform.cgw.connectivity

import java.net.URL
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer.SumTypeRepr

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import static extension org.eclipse.mita.program.model.ModelUtils.getArgumentValue

class BcxRestClientGenerator extends RestClientGenerator {
	override generateSignalInstanceSetter(SignalInstance signalInstance, String valueVariableName) {
		val writeMethod = StaticValueInferrer.infer(signalInstance.getArgumentValue("writeMethod"), [])?.castOrNull(SumTypeRepr);
		val url = new URL(configuration.getString('endpointBase'));
		val port = if(url.port < 0) 80 else url.port;
		
		codeFragmentProvider.create('''
			// 1: 0-byte, 4: braces, quot. marks, colon, comma, 8: |deviceid|
			uint32_t bufSize = «valueVariableName»->length + 1 + CELLULAR_ICCID_MAX_LENGTH + 6 + 8;
			char buf[bufSize];
			snprintf(buf, bufSize, "{\"deviceid\":%s,%.*s}", iccid, «valueVariableName»->length, «valueVariableName»->data);
			buf[«valueVariableName»->length] = 0;
			Retcode_T exception = CellularHttp_Post("«url.host»", «signalInstance.getArgumentValue("endpoint").code», «port», buf, false);
			
			if (exception == RETCODE_OK)
			{
				exception = Http_WaitEvent(5,120000);
			}
			
			return exception;
		''')
	}
}