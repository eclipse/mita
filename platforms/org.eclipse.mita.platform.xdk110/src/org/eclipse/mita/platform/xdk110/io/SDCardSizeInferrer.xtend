package org.eclipse.mita.platform.xdk110.io

import org.eclipse.mita.program.inferrer.GenericPlatformSizeInferrer
import org.eclipse.mita.program.SignalInstance

class SDCardSizeInferrer extends GenericPlatformSizeInferrer {
	
	override getLengthParameterName(SignalInstance sigInst) {
		return SDCardGenerator.getSizeName(sigInst);
	}
	
}