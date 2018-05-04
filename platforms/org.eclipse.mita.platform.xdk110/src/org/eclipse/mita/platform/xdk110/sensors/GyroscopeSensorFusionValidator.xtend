package org.eclipse.mita.platform.xdk110.sensors

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.platform.Sensor
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.xtext.validation.ValidationMessageAcceptor
import org.yakindu.base.expressions.expressions.FeatureCall

class GyroscopeSensorFusionValidator implements IResourceValidator {
	
	def pred(Modality m) {
		
	}
		
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		val mas = program.eAllContents.filter(FeatureCall)
			.map[it.feature].toList;
		
		val sensorAccess = program.eAllContents
			.filter(FeatureCall)
			.findFirst[f |
				val m = f.feature
				if(m instanceof Modality) {
					return (m.eContainer as Sensor).name == "GyroscopeSensorFusion" && m.name != "accuracy"
				}
				return false
			];
		
		if(sensorAccess === null) {
			return;
		}
		
		val msg = "Using the basic gyroscope might require the device to be still for a few seconds for calibration upon booting. To find out if data is reliable use 'gyroscope.accuracy'.";
		acceptor.acceptWarning(msg, sensorAccess, null, 0, "CALIBRATED_GYROSCOPE");
	}
	
}
