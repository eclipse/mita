package org.eclipse.mita.platform.arduino.uno.platform

import java.util.HashSet
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.mita.base.expressions.ArgumentExpression
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Signal
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.validation.ValidationMessageAcceptor
import org.eclipse.mita.program.validation.MethodCall
import org.eclipse.mita.program.validation.MethodCall.MethodCallSigInst

class Validation implements IResourceValidator {
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		val functionCalls1 = program.eAllContents.filter(FeatureCall).filter[it.operationCall].toList;
		val functionCalls2 = program.eAllContents.filter(ElementReferenceExpression).filter[it.operationCall].toList;
		
		val sigInstAccesses = (
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
			]).filterNull.filter(MethodCallSigInst)
		
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
		
		val gpios = filterSigInstName.apply("GPIO").toSet
		
		val writes = sigInstAccesses.filter[
			if(it.method instanceof GeneratedFunctionDefinition) {
				it.method.name == "write"
			} else {
				false
			}
		].toSet
		
		val gpioWrites = new HashSet(gpios) => [retainAll(writes)]
		
		gpioWrites.forEach[validateGpioWrite(it, acceptor)]
	}
	
	def validateGpioWrite(MethodCallSigInst call, ValidationMessageAcceptor acceptor) {
		val init = call.sigInst.initialization as ElementReferenceExpression;
		val value = init.arguments.get(1).value
		if (value instanceof ElementReferenceExpression){
			if(value.reference.toString.contains("INPUT")){
				acceptor.acceptError("Can not write to inputs", call.source, call.structFeature, 0, "CANT_WRITE_TO_INPUTS")
			}
		}
	}
}