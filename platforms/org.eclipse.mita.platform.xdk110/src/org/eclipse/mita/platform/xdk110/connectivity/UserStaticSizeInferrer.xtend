package org.eclipse.mita.platform.xdk110.connectivity

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.yakindu.base.expressions.expressions.FeatureCall

class UserStaticSizeInferrer extends ElementSizeInferrer {
	
	override infer(EObject obj) {
		if (obj instanceof FeatureCall) {
			val instance = obj.owner;
			val method = obj.feature;
			if(method instanceof GeneratedFunctionDefinition) {
				if(method.name != "read") {
					return newInvalidResult(obj, "Can't infer for non-read method");
				}
				if(instance instanceof FeatureCall) {
					val signal = instance.feature;
					if(signal instanceof SignalInstance) {
						val lengthArg = ModelUtils.getArgumentValue(signal, 'length');
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