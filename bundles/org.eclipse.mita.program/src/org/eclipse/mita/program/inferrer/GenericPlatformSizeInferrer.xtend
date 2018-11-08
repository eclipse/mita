package org.eclipse.mita.program.inferrer

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.expressions.ElementReferenceExpression

class GenericPlatformSizeInferrer extends ElementSizeInferrer {

	def String getLengthParameterName(SignalInstance sigInst) {
		return 'length';
	}

	override infer(EObject obj) {
		val instance = if(obj instanceof ElementReferenceExpression) {
			if(obj.isOperationCall && obj.arguments.size > 0) {
				obj.arguments.head.value; 
			}
		}
		else if (obj instanceof FeatureCall) {
			obj.owner;
		}
		val method = if(obj instanceof ElementReferenceExpression) {
			if(obj.isOperationCall && obj.arguments.size > 0) {
				obj.reference;
			}
		}
		else if (obj instanceof FeatureCall) {
			obj.feature;
		}
		if(instance !== null && method !== null) {
			if(method instanceof GeneratedFunctionDefinition) {
				if(method.name != "read") {
					return newInvalidResult(obj, "Can't infer for non-read method");
				}
				if(instance instanceof FeatureCall) {
					val signal = instance.feature;
					if(signal instanceof SignalInstance) {
						val lengthArg = ModelUtils.getArgumentValue(signal, signal.lengthParameterName);
						if(lengthArg !== null) {
							val maxLength = StaticValueInferrer.infer(lengthArg, [ ]);
							return newValidResult(obj, maxLength as Integer);	
						}
					}
				}
			}			
		}
		return newInvalidResult(obj, "Can't infer for non-feature call");
	}
	
}
