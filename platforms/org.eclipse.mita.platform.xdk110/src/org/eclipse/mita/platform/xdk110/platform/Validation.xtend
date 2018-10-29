package org.eclipse.mita.platform.xdk110.platform

/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.mita.base.expressions.ArgumentExpression
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Signal
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.xtext.validation.ValidationMessageAcceptor
import java.util.Set
import java.util.HashSet
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.mita.program.validation.MethodCall
import org.eclipse.mita.program.validation.MethodCall.MethodCallSigInst
import org.eclipse.mita.program.validation.MethodCall.MethodCallModality
import org.eclipse.mita.platform.xdk110.sensors.NoiseSensorValidator
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.TimeIntervalEvent
import org.eclipse.mita.program.ProgramBlock

class Validation implements IResourceValidator {

	@Inject ElementSizeInferrer sizeInferrer
		
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		val functionCalls1 = program.eAllContents.filter(FeatureCall).filter[it.operationCall].toList;
		val functionCalls2 = program.eAllContents.filter(ElementReferenceExpression).filter[it.operationCall].toList;
		
		// the following is extension method hell
		// EObject source = it, SignalInstance sigInst, int structFeature
		// ArgumentExpression source = it, Operation writeMethod, SignalInstance sigInst
		val sigInstOrModalityAccesses = (
			functionCalls1.map[
				val ArgumentExpression source = it;
				val method = it.feature;
				val owner = it.owner;
				if(owner instanceof FeatureCall) {
					val sigInst = owner.feature;
					if(source === null || method === null || sigInst === null) {
						return null;
					}
					return MethodCall.cons(source, method, sigInst, ExpressionsPackage.Literals.FEATURE_CALL__FEATURE)
				}
				return null;
			] + functionCalls2.map[
				val ArgumentExpression source = it;
				val method = it.reference;
				if(method instanceof Operation) {
					val sigInst = ModelUtils.getArgumentValue(method, it, "self");
					if(source === null || method === null || sigInst === null) {
						return null;
					}
					return MethodCall.cons(source, method, sigInst, ExpressionsPackage.Literals.ELEMENT_REFERENCE_EXPRESSION__REFERENCE)
				}
				return null;
			]).filterNull
		
		val sigInstAccesses = sigInstOrModalityAccesses.filter(MethodCallSigInst);
		val modalityAccesses = sigInstOrModalityAccesses.filter(MethodCallModality);
		
		val filterSigInstName = [String name | 
			return sigInstAccesses.filter[
				val init = it.sigInst.initialization;
				if(init instanceof ElementReferenceExpression) {
					val ref = init.reference;
					if(ref instanceof Signal) {
						val res = ref.eContainer;
						if(res instanceof AbstractSystemResource) {
							return res.name == name
						}
					}	
				}
				return false;
			]
		]
		
		val filterModalityName = [String name | 
			return modalityAccesses.filter[
				val modality = it.modality;
				val res = modality.eContainer;
				if(res instanceof AbstractSystemResource) {
					return res.name == name
				}
				return false;
			]
		]
		
		val i2cs = filterSigInstName.apply("I2C").toSet
		val gpios = filterSigInstName.apply("GPIO").toSet
		
		val noises = filterModalityName.apply("noise_sensor").toSet;
		
		val reads = sigInstAccesses.filter[
			if(it.method instanceof GeneratedFunctionDefinition) {
				it.method.name == "read"
			} else {
				false
			}
		].toSet
		val writes = sigInstAccesses.filter[
			if(it.method instanceof GeneratedFunctionDefinition) {
				it.method.name == "write"
			} else {
				false
			}
		].toSet
		
		val i2cReads   = new HashSet(i2cs  ) => [retainAll(reads)]
		val i2cWrites  = new HashSet(i2cs  ) => [retainAll(writes)]
		val gpioReads  = new HashSet(gpios ) => [retainAll(reads)]
		val gpioWrites = new HashSet(gpios ) => [retainAll(writes)]
				
		i2cReads.forEach[validateI2cReadWrite(it.source, it.sigInst, it.structFeature, "Read", "read from", acceptor)]
		i2cWrites.forEach[validateI2cReadWrite(it.source, it.sigInst, it.structFeature, "Write", "write to", acceptor)]
		
		i2cWrites.forEach[validateI2cWriteLength(it.source, it.method, it.sigInst, acceptor)]
		
		gpioReads.forEach[validateGpioRead(it, acceptor)]
		gpioWrites.forEach[validateGpioWrite(it, acceptor)]
		
		noises.forEach[validateNoiseRead(noises, it, acceptor)]
	}
	
	/*
	 * We validate if in timed events the noise sensor is only sampled as fast as it has samples here. 
	 * Since this is equivalent to the halting problem we only emit warnings, not errors (for example in conflicting control flow) <-> we assume some kind of worst case: every read happens at least once.
	 * Right now this is a bad estimate for if/else, where it is too pessimistic, and for loops, where it might be too optimistic.
	 * I've also decided to not do this kind of validation in non-time event handlers like every button_one.pressed
	 * since there the real constraints are timeout (which is handled by org.eclipse.mita.platform.xdk110.sensors.NoiseSensorValidator) 
	 * and the real world (which we don't know anything about). 
	 */
	def validateNoiseRead(Set<MethodCallModality> noiseReads, MethodCallModality mcm, ValidationMessageAcceptor acceptor) {
		val setups = mcm.source.eResource.resourceSet.allContents.filter(Program).flatMap[it.setup.iterator].filter[it.type?.name == NoiseSensorValidator.NOISE_SENSOR_TYPE_NAME];
		val sampleTime_expr = NoiseSensorValidator.getTimePerSampleInMs(setups.head);
		
		var outerProgramBlock = EcoreUtil2.getContainerOfType(mcm.source, ProgramBlock);
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
			if(eventSampleTime < actualSampleTime && !ModelUtils.isInTryCatchFinally(mcm.source)) {
				val fmtString = "Noise samples won't be calculated fast enough for how often you are sampling. Consider increasing sampling frequency to %d or increasing your event handler interval to %dms.";
				val msg = String.format(fmtString, Math.ceil(256.0 * 1000.0/(eventSampleTime/numberOfPreviousReadsInThisEventHandler)) as int, actualSampleTime as int);
				acceptor.acceptWarning(msg, mcm.source, null, 0, "");
				acceptor.acceptWarning(msg, event.interval, null, 0, "");
			}
		}
	}
	
	def validateGpioRead(MethodCallSigInst call, ValidationMessageAcceptor acceptor) {
		val init = call.sigInst.initialization as ElementReferenceExpression;
		val signal = init.reference as Signal;
		if(signal.name.contains("Out")) {
			acceptor.acceptError("Can not read from " + signal.name, call.source, call.structFeature, 0, "CANT_READ_FROM_" + signal.name.toUpperCase)
		}
	}
	def validateGpioWrite(MethodCallSigInst call, ValidationMessageAcceptor acceptor) {
		val init = call.sigInst.initialization as ElementReferenceExpression;
		val signal = init.reference as Signal;
		if(signal.name.contains("In")) {
			acceptor.acceptError("Can not write to " + signal.name, call.source, call.structFeature, 0, "CANT_WRITE_TO_" + signal.name.toUpperCase)
		}
	}
	
	//ExpressionsPackage.FEATURE_CALL__FEATURE
	
	// precondition: none of these casts will fail --> caller needs to filter those that will fail
	// assumption: this featureCall is a read or write on a signalInstance on I2C signals
	def validateI2cReadWrite(EObject source, SignalInstance sigInst, EStructuralFeature structFeature, String which, String msg, ValidationMessageAcceptor acceptor) {
		val mode = StaticValueInferrer.infer(ModelUtils.getArgumentValue(sigInst, "mode"), []);
		if(mode instanceof Enumerator) {
			if(!mode.name.contains(which)) {
				acceptor.acceptError("Can not " + msg + " signal instance", source, structFeature, 0, "CANT_" + msg.toUpperCase.replace(" ", "_") + "_SIGINST")
			}
		}
	}
	
	// precondition: none of these casts will fail --> caller needs to filter those that will fail
	// assumption: this operation is a write on a signalInstance on I2C signals
	def validateI2cWriteLength(ArgumentExpression source, Operation writeMethod, SignalInstance sigInst, ValidationMessageAcceptor acceptor) {
		//signal array_register_uint8(address: uint8, length: uint8, mode: I2CMode = ReadWrite): array<uint8>
		val init = sigInst.initialization as ElementReferenceExpression;
		val signal = init.reference as Signal;
		if(!signal.name.startsWith("array_register")) {
			return;
		}
		val specifiedLength = StaticValueInferrer.infer(ModelUtils.getArgumentValue(sigInst, "length"), []);
		if(specifiedLength instanceof Integer) {
			val argumentArray = ModelUtils.getArgumentValue(writeMethod, source, "value");
			val arraySize = sizeInferrer.infer(argumentArray);
			if(arraySize instanceof ValidElementSizeInferenceResult) {
				val actualLength = arraySize.elementCount;
				if(actualLength != specifiedLength) {
					acceptor.acceptError("passed array has invalid size: " + actualLength + ", should be: " + specifiedLength, argumentArray, null, 0, "PASSED_ARRAY_HAS_INVALID_SIZE")
				}
			}	
		}
		
	}

}



