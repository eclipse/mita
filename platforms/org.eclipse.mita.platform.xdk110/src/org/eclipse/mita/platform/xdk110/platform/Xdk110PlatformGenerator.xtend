package org.eclipse.mita.platform.xdk110.platform

import com.google.common.base.Optional
import com.google.inject.Inject
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Platform
import org.eclipse.mita.platform.xdk110.connectivity.AdcGenerator
import org.eclipse.mita.platform.xdk110.connectivity.AdcGenerator.SignalInfo
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.xtext.EcoreUtil2

class Xdk110PlatformGenerator extends AbstractSystemResourceGenerator {
	
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
		return codeFragmentProvider.create('''Retcode_T XDK110_powerStatus_read(PowerStatus* result);''').addHeader("xdk110Types.h", false);
	}
	
	override generateEnable() {
		return codeFragmentProvider.create('''''').setPreamble('''
		Retcode_T XDK110_powerStatus_read(PowerStatus* result) {
			uint16_t batteryVoltage = 0;
			uint16_t* batteryVoltagePtr = &batteryVoltage;
			
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
			PowerStatus «varName»;
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
	
}