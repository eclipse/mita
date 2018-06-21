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
import org.eclipse.mita.base.expressions.ArgumentExpression
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.platform.Bus
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
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.emf.ecore.EStructuralFeature

class Validation implements IResourceValidator {

	@Inject ElementSizeInferrer sizeInferrer
	
	private static class MethodCall {
		final ArgumentExpression source
		final SignalInstance sigInst
		final EStructuralFeature structFeature
		final Operation method
		
		private new(ArgumentExpression ae, Operation op, SignalInstance si, EStructuralFeature sf) {
			source = ae;
			sigInst = si;
			structFeature = sf;
			method = op;
		}
		static dispatch def cons(ArgumentExpression ae, Operation op, SignalInstance si, EStructuralFeature sf) {
			new MethodCall(ae,op,si,sf);
		}
		static dispatch def cons(Object _1, Object _2, Object _3, Object _4) {
			null;
		}		
	}
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		val functionCalls1 = program.eAllContents.filter(FeatureCall).filter[it.operationCall].toList;
		val functionCalls2 = program.eAllContents.filter(ElementReferenceExpression).filter[it.operationCall].toList;
		
		// the following is extension method hell
		// EObject source = it, SignalInstance sigInst, int structFeature
		// ArgumentExpression source = it, Operation writeMethod, SignalInstance sigInst
		
		val i2cs = (
			functionCalls1.map[
				val ArgumentExpression source = it;
				val method = it.feature;
				val owner = it.owner;
				if(owner instanceof FeatureCall) {
					val sigInst = owner.feature;
					if(method === null || sigInst === null) {
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
					if(method === null || sigInst === null) {
						return null;
					}
					return MethodCall.cons(source, method, sigInst, ExpressionsPackage.Literals.ELEMENT_REFERENCE_EXPRESSION__REFERENCE)
				}
				return null;
			]).filterNull.filter[
				val init = it.sigInst.initialization;
				if(init instanceof ElementReferenceExpression) {
					val ref = init.reference;
					if(ref instanceof Signal) {
						val i2c = ref.eContainer;
						if(i2c instanceof Bus) {
							return i2c.name == "I2C"
						}
					}	
				}
				return false;
			].toList
		
				
		val reads = i2cs.filter[
			if(it.method instanceof GeneratedFunctionDefinition) {
				it.method.name == "read"
			} else {
				false
			}
		]
		val writes = i2cs.filter[
			if(it.method instanceof GeneratedFunctionDefinition) {
				it.method.name == "write"
			} else {
				false
			}
		]
		
		reads.forEach[validateI2cReadWrite(it.source, it.sigInst, it.structFeature, "Read", "read from", acceptor)]
		writes.forEach[validateI2cReadWrite(it.source, it.sigInst, it.structFeature, "Write", "write to", acceptor)]
		
		writes.forEach[validateI2cWriteLength(it.source, it.method, it.sigInst, acceptor)]
		
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



