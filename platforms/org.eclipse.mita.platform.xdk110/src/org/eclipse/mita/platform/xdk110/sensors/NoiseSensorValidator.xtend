package org.eclipse.mita.platform.xdk110.sensors

import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.TimeIntervalEvent
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.mita.program.validation.MethodCall.MethodCallModality
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.validation.ValidationMessageAcceptor

class NoiseSensorValidator implements IResourceValidator {
	
	public static val DEFAULT_SAMPLING_FREQUENCY = 2560;
	public static val MINIMUM_SAMPLING_FREQUENCY = 6;
	public static val MAXIMUM_SAMPLING_FREQUENCY = 45000;
	public static val MINIMUM_SAMPLE_TIME = 256 * 1000.0 / MAXIMUM_SAMPLING_FREQUENCY
	public static val DEFAULT_TIMEOUT = 100;
	public static val NOISE_SENSOR_TYPE_NAME = "noise_sensor";
	public static val TIMEOUT_SMALLER_THAN_SAMPLING_TIME = "Timeout is smaller than sampling time (~%f for 256 samples). This could lead to exceptions being thrown. Consider increasing timeout to at least %d or increasing sampling frequency to at least %d.";
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		if(context instanceof SystemResourceSetup) {
			if(context.type?.name == NOISE_SENSOR_TYPE_NAME) {
				val samplingFrequency_expr = getSamplingFrequency(context);
				if(samplingFrequency_expr.key > MAXIMUM_SAMPLING_FREQUENCY) {
					acceptor.acceptError('''Sampling frequency too high («samplingFrequency_expr.key»), maximum is 45000.''', samplingFrequency_expr.value, null, 0, "");
					return;
				}
				if(samplingFrequency_expr.key < MINIMUM_SAMPLING_FREQUENCY) {
					acceptor.acceptError('''Sampling frequency too low («samplingFrequency_expr.key»), minimum is 6.''', samplingFrequency_expr.value, null, 0, "");
					return;
				}
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
	
	/*
	 * We validate if in timed events the noise sensor is only sampled as fast as it has samples here. 
	 * Since this is equivalent to the halting problem we only emit warnings, not errors (for example in conflicting control flow) <-> we assume some kind of worst case: every read happens at least once.
	 * Right now this is a bad estimate for if/else, where it is too pessimistic, and for loops, where it might be too optimistic.
	 * I've also decided to not do this kind of validation in non-time event handlers like every button_one.pressed
	 * since there the real constraints are timeout (which is handled by org.eclipse.mita.platform.xdk110.sensors.NoiseSensorValidator) 
	 * and the real world (which we don't know anything about). 
	 */
	def static validateNoiseRead(Set<MethodCallModality> noiseReads, MethodCallModality mcm, ValidationMessageAcceptor acceptor) {
		val setups = mcm?.source.eResource.resourceSet.allContents?.filter(Program)?.flatMap[it.setup.iterator]?.filter[it.type?.name == NOISE_SENSOR_TYPE_NAME];
		val sampleTime_expr = NoiseSensorValidator.getTimePerSampleInMs(setups?.head);
		
		var outerProgramBlock = EcoreUtil2.getContainerOfType(mcm.source, ProgramBlock);
		if(outerProgramBlock === null) {
			return;
		}
		var outerMost = false;
		while(!outerMost) {
			val next = EcoreUtil2.getContainerOfType(outerProgramBlock.eContainer, ProgramBlock);
			if(next === null) {
				outerMost = true;
			}
			else {
				outerProgramBlock = next;
			}
		}
		
		val nearbyReads = outerProgramBlock.eAllContents.filter[obj | noiseReads.findFirst[it.source == obj] !== null].toList;
		val previousNoiseReads = nearbyReads.takeWhile[it !== mcm.source].toList;
		
		val eventHandler = EcoreUtil2.getContainerOfType(mcm.source, EventHandlerDeclaration);
		val event = eventHandler.event;
		val numberOfPreviousReadsInThisEventHandler = previousNoiseReads.length + 1;
		val actualSampleTime = sampleTime_expr.key * numberOfPreviousReadsInThisEventHandler;
		if(event instanceof TimeIntervalEvent) {
			val eventSampleTime = ModelUtils.getIntervalInMilliseconds(event);
			val msgFasterThanXdkIsCapable = '''You can't sample the noise sensor this often. Minimum time per sample is «Math.ceil(MINIMUM_SAMPLE_TIME) as int»ms. This means that you will get exceptions or eventually overflow the event queue.''';
			val msgFasterThanConfigured = '''Noise samples won't be calculated fast enough for how often you are sampling, which means that you will get exceptions. Consider increasing sampling frequency to «Math.ceil(256.0 * 1000.0/(eventSampleTime/numberOfPreviousReadsInThisEventHandler)) as int» or increasing your event handler interval to «actualSampleTime as int»ms.''';
			if(eventSampleTime/numberOfPreviousReadsInThisEventHandler < MINIMUM_SAMPLE_TIME) {
				acceptor.acceptWarning(msgFasterThanXdkIsCapable, event.interval, null, 0, "");
				acceptor.acceptWarning(msgFasterThanXdkIsCapable, mcm.source, null, 0, "");
				// don't do additional validation, since you can't fix this other than sampling less often.
				return;
			}
			if(eventSampleTime < actualSampleTime && !ModelUtils.isInTryCatchFinally(mcm.source)) {
				acceptor.acceptWarning(msgFasterThanConfigured + " Alternatively you should catch exceptions here.", mcm.source, null, 0, "");
				acceptor.acceptWarning(msgFasterThanConfigured, event.interval, null, 0, "");
			}
		}
	}
	
}