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
		«IF needToSetupAdc(this.context)»
		«adcGenerator.generateSetup(#[new SignalInfo(
			"XDK110_powerStatus_ADC",
			"ADC_ACQ_TIME_64",
			"ADC_ENABLE_CH7",
			"ADC_REF_2V5",
			"ADC_RESOLUTION_12BIT"
		)])»
		«ENDIF»
		''')
	}
	
	override generateAdditionalHeaderContent() {
		return codeFragmentProvider.create('''Retcode_T XDK110_powerStatus_read(uint16_t* result);''')
	}
	
	override generateEnable() {
		return codeFragmentProvider.create('''''').setPreamble('''
		«IF needToSetupAdc(this.context)»
		Retcode_T XDK110_powerStatus_read(uint16_t* result) {
			«adcGenerator.generateSignalInstanceGetter("XDK110_powerStatus_ADC", 2500, 12, "result")»
		}
		«ENDIF»
		''');
	}
	
	def isPowerStatusUsed(CompilationContext p) {
		p.allUnits.map[it.eAllContents.filter(ModalityAccess).exists[
			val m = it.modality;
			val sysResource = m.eContainer as AbstractSystemResource;
			m.name == "powerStatus" && sysResource instanceof Platform && sysResource.name == "XDK110"
		]].exists[it];
	}
	
	def adcIsAlreadySetup(CompilationContext p) {
		p.allUnits.map[it.setup.exists[it.type?.name == "ADC"]].exists[it];
	}
	
	def needToSetupAdc(CompilationContext p) {
		return p.isPowerStatusUsed && !p.adcIsAlreadySetup;
	}
	
	// it would be nice if we had access to the compilation context here, but we are called from 
	// StatementGenerator.code(ModalityAccessPreparation stmt) which configures CompilationContext with null.
	def Optional<SignalInstance> adcIsSetupAndChannel7IsConfigured(Program p) {
		val ch7Used = p.setup
				.filter[it.type?.name == "ADC"]
				.flatMap[it.signalInstances
					.map[it -> ModelUtils.getArgumentValue(it, "channel")]]
				.filter[it.value !== null]
				.map[it.key -> StaticValueInferrer.infer(it.value, [])]
				.filter[it.value !== null]
				.map[
					val v = it.value; 
					if(v instanceof Enumerator) {return it.key -> v} else {return null}]
				.filterNull
				.filter[it.value.name == "CH7"]
				.map[it.key]
		return Optional.fromNullable(ch7Used.head);
	}
	
	def powerStatusReadMethod(Program p) {
		adcIsSetupAndChannel7IsConfigured(p).transform[it.baseName + "_Read"].or("XDK110_powerStatus_read")
	}
	
	override generateAccessPreparationFor(ModalityAccessPreparation accessPreparation) {
		val varName = accessPreparation.uniqueIdentifier.toFirstLower;
		
		return codeFragmentProvider.create('''
			uint16_t batteryVoltage = 0;
			exception = «powerStatusReadMethod(EcoreUtil2.getContainerOfType(accessPreparation, Program))»(&batteryVoltage);
			«generateExceptionHandler(accessPreparation, "exception")»;
			PowerStatus «varName»;
			if(batteryVoltage > 2100) {
				«varName».tag = PowerStatus_Corded_e;
			}
			else {
				«varName».tag = PowerStatus_Battery_e;
				«varName».data = 100 * batteryVoltage / 2087.0f;
			}
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