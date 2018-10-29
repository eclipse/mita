package org.eclipse.mita.platform.xdk110.sensors

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.xtext.validation.ValidationMessageAcceptor
import org.eclipse.mita.program.inferrer.StaticValueInferrer

class NoiseSensorValidator implements IResourceValidator {
	
	public static val DEFAULT_SAMPLING_FREQUENCY = 2560;
	public static val DEFAULT_TIMEOUT = 100;
	public static val NOISE_SENSOR_TYPE_NAME = "noise_sensor";
	public static val TIMEOUT_SMALLER_THAN_SAMPLING_TIME = "Timeout is smaller than sampling time (~%f for 256 samples). This could lead to exceptions being thrown. Consider increasing timeout to at least %d or increasing sampling frequency to at least %d.";
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		if(context instanceof SystemResourceSetup) {
			if(context.type?.name == NOISE_SENSOR_TYPE_NAME) {
				// one noise sample is calculated with 256 microphone samples
				val timePerSampleInMs_expr = getTimePerSampleInMs(context);
				val timePerSampleInMs = timePerSampleInMs_expr.key;
				if(timePerSampleInMs.isNaN) {
					acceptor.acceptError("Invalid sampling frequency", timePerSampleInMs_expr.value, null, 0, "");
					return;
				}
				val timeout_expr = getTimeout(context);
				val timeout = timeout_expr.key;
				if(timeout < timePerSampleInMs) {
					val minSamplingFrequency = Math.ceil(256.0 * 1000.0/timeout) as int;
					acceptor.acceptWarning(String.format(TIMEOUT_SMALLER_THAN_SAMPLING_TIME, timePerSampleInMs, timePerSampleInMs.intValue, minSamplingFrequency), timePerSampleInMs_expr.value, null, 0, "");
					acceptor.acceptWarning(String.format(TIMEOUT_SMALLER_THAN_SAMPLING_TIME, timePerSampleInMs, timePerSampleInMs.intValue, minSamplingFrequency), timeout_expr.value, null, 0, "");
				}
			}
		}
	}
	
	def static getTimeout(SystemResourceSetup setup) {
		val expr = setup?.getConfigurationItemValue("timeout");
		val value = StaticValueInferrer.infer(expr, [
			println("Warning: no timeout")
		]);
		val timeout = if(value instanceof Integer) {
			value;
		}
		else {
			DEFAULT_TIMEOUT;
		}
		return timeout -> expr;
	}
	
	def static getSamplingFrequency(SystemResourceSetup setup) {
		val expr = setup?.getConfigurationItemValue("samplingFrequency");
		val value = StaticValueInferrer.infer(expr, [
			println("Warning: no samplingFrequency")
		]);
		val samplingFrequency = if(value instanceof Integer) {
			value;
		}
		else {
			DEFAULT_SAMPLING_FREQUENCY;
		}
		return samplingFrequency -> expr;
	}
	
	def static getTimePerSampleInMs(SystemResourceSetup setup) {
		val f_expr = getSamplingFrequency(setup);
		val f = f_expr.key;
		if(f > 0) {
			return (256.0 * 1000.0/f) -> f_expr.value;
		}
		return Double.NaN -> f_expr.value;
	}
	
}