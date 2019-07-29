package org.eclipse.mita.platform.xdk110.sensors

import com.google.inject.Inject
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.GeneratorUtils

class NoiseSensorGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	protected extension GeneratorUtils
	
	override generateSetup() {
		return codeFragmentProvider.create('''
			return NoiseSensor_Setup(«configuration.getLong("samplingFrequency")»);
		''').addHeader('XDK_NoiseSensor.h', true)
	}
	
	override generateEnable() {
		return codeFragmentProvider.create('''
			return NoiseSensor_Enable();
		''').addHeader('XDK_NoiseSensor.h', true)
		.setPreamble(codeFragmentProvider.create('''
		#define NOISE_SENSOR_READ_TIMEOUT «configuration.getLong("timeout")»
		'''))
	}
	
	override generateAdditionalHeaderContent() {
		return codeFragmentProvider.create('''
			Retcode_T readNoiseSensor(float *result);
		''');
	}
	
	override generateAdditionalImplementation() {
		return codeFragmentProvider.create('''
			Retcode_T readNoiseSensor(float *result) {
				NoiseSensor_ReadRmsValue(result, NOISE_SENSOR_READ_TIMEOUT);
			}
		''');
	}
	
	override generateAccessPreparationFor(ModalityAccessPreparation accessPreparation) {
		val dataVariable = accessPreparation.uniqueIdentifier.toFirstLower;
		return codeFragmentProvider.create('''
			float «dataVariable»;
			exception = readNoiseSensor(&«dataVariable»);
			«generateExceptionHandler(accessPreparation, 'exception')»
		''');
	}
	
	override generateModalityAccessFor(ModalityAccess modality) {
		val dataVariable = modality.preparation.uniqueIdentifier.toFirstLower;
		return codeFragmentProvider.create('''
			«dataVariable»
		''')
	}
	
}