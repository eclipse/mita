package org.eclipse.mita.program.inferrer

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.model.ModelUtils

class GenericPlatformSizeInferrer extends ElementSizeInferrer {

	def String getLengthParameterName(SignalInstance sigInst) {
		return 'length';
	}

	override protected _doInfer(ElementReferenceExpression obj, AbstractType type) {
		val instance = if(obj.isOperationCall && obj.arguments.size > 0) {
			obj.arguments.head.value; 
		}
		
		val method = if(obj.isOperationCall && obj.arguments.size > 0) {
			obj.reference;
		}
		if(instance !== null && method !== null) {
			if(method instanceof GeneratedFunctionDefinition) {
				if(method.name != "read") {
					return newInvalidResult(obj as EObject, "Can't infer for non-read method");
				}
				if(instance instanceof FeatureCall) {
					val signal = instance.reference;
					if(signal instanceof SignalInstance) {
						val lengthArg = ModelUtils.getArgumentValue(signal, signal.lengthParameterName);
						if(lengthArg !== null) {
							val maxLength = StaticValueInferrer.infer(lengthArg, [ ]);
							return newValidResult(obj as EObject, maxLength as Long);	
						}
					}
				}
			}			
		}
		return newInvalidResult(obj, "Can't infer for non-function call");
	}
	
}
