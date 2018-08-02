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

class Validation implements IResourceValidator {

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
		
		override toString() {
			val setup = EcoreUtil2.getContainerOfType(sigInst, SystemResourceSetup)
			return '''�setup?.name�.�sigInst.name�.�method.name�(�FOR arg : source.arguments SEPARATOR(", ")��StaticValueInferrer.infer(arg.value, [])?.toString?:"null"��ENDFOR�)'''
		}
		
		override hashCode() {
			toString.hashCode()
		}
		
		override equals(Object arg0) {
			if(arg0 instanceof MethodCall) {
				return toString == arg0.toString;
			}
			return super.equals(arg0)
		}
	}
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		val functionCalls1 = program.eAllContents.filter(FeatureCall).filter[it.operationCall].toList;
		val functionCalls2 = program.eAllContents.filter(ElementReferenceExpression).filter[it.operationCall].toList;
		
		val sigInstAccesses = (
			functionCalls1.map[
				val ArgumentExpression source = it;
				val method = it.reference;
				val owner = it.arguments.head.value;
				if(owner instanceof FeatureCall) {
					val sigInst = owner.reference;
					if(source === null || method === null || sigInst === null) {
						return null;
					}
					return MethodCall.cons(source, method, sigInst, ExpressionsPackage.Literals.ELEMENT_REFERENCE_EXPRESSION__REFERENCE)
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
	
	def validateGpioWrite(MethodCall call, ValidationMessageAcceptor acceptor) {
		val init = call.sigInst.initialization as ElementReferenceExpression;
		val value = init.arguments.get(1).value
		if (value instanceof ElementReferenceExpression){
			if(value.reference.toString.contains("INPUT")){
				acceptor.acceptError("Can not write to inputs", call.source, call.structFeature, 0, "CANT_WRITE_TO_INPUTS")
			}
		}
	}
}