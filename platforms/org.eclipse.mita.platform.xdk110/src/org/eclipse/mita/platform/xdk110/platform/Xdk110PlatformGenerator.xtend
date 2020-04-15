package org.eclipse.mita.platform.xdk110.platform

import com.google.inject.Inject
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.platform.xdk110.connectivity.AdcGenerator
import org.eclipse.mita.platform.xdk110.connectivity.AdcGenerator.SignalInfo
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.MainSystemResourceGenerator

import static extension org.eclipse.mita.base.util.BaseUtils.computeOrigin

class Xdk110PlatformGenerator extends MainSystemResourceGenerator {
	
	@Inject
	extension GeneratorUtils
	
	@Inject
	AdcGenerator adcGenerator;
	
	override generateSetup() {
		return codeFragmentProvider.create('''
		«adcGenerator.generateSetup(#[new SignalInfo(
			"XDK110_powerStatus_ADC",
			"ADC_ACQ_TIME_64",
			"ADC_ENABLE_CH7",
			"ADC_REF_2V5",
			"ADC_RESOLUTION_12BIT"
		)])»
		''')
	}
	
	override generateAdditionalHeaderContent() {
		return codeFragmentProvider.create('''Retcode_T XDK110_powerStatus_read(PowerStatus_t* result);''').addHeader("xdk110Types.h", false);
	}
	
	override generateEnable() {
		return codeFragmentProvider.create('''''').setPreamble('''
		Retcode_T XDK110_powerStatus_read(PowerStatus_t* result) {
			uint16_t batteryVoltage = 0;
			uint16_t* batteryVoltagePtr = &batteryVoltage;
			Retcode_T exception = NO_EXCEPTION;
			
			«adcGenerator.generateSignalInstanceGetter("XDK110_powerStatus_ADC", 2500, 12, "batteryVoltagePtr")»
			
			«generateExceptionHandler(null, "exception")»
			
			// 0% is 3V, internal voltage divider -> 1.5V
			batteryVoltage -= 1500;
			
			// experimentally determined threshold
			if(batteryVoltage > 600) {
				result->tag = PowerStatus_Corded_e;
			}
			else {
				result->tag = PowerStatus_Battery_e;
				result->data.Battery = 100 * batteryVoltage / 587.0f;
			}
			return exception;
		}
		''')
		.addHeader("xdk110Types.h", false);
	}
				
	def powerStatusReadMethod() {
		"XDK110_powerStatus_read"
	}
	
	override generateAccessPreparationFor(ModalityAccessPreparation accessPreparation) {
		val varName = accessPreparation.uniqueIdentifier.toFirstLower;
		
		return codeFragmentProvider.create('''
			PowerStatus_t «varName»;
			exception = «powerStatusReadMethod»(&«varName»);
			«generateExceptionHandler(accessPreparation, "exception")»
		''')
		.addHeader("xdk110Types.h", false)
	}
	
	override generateModalityAccessFor(ModalityAccess modality) {
		val varName = modality.preparation.uniqueIdentifier.toFirstLower;
		return codeFragmentProvider.create('''
			«varName»
		''')
		.addHeader("xdk110Types.h", false)
	}
	
	override getEventHandlerPayloadQueueSize(EventHandlerDeclaration handler) {
		val type = BaseUtils.getType(handler.event.computeOrigin);
		if(type.name == "string") {
			return 2;
		}
		return 10;
	}
	
}