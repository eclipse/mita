package org.eclipse.mita.platform.xdk110.connectivity

import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer.SumTypeRepr

class HonoGenerator extends MqttGenerator {
	
	override protected getTopicName(SignalInstance instance) {
		val auth = StaticValueInferrer.infer(configuration.getExpression("authentication"), []);
		
		if(auth instanceof SumTypeRepr) {
			if(auth.name == 'Authenticated') {
				return instance.instanceOf.name;
			} else if(auth.name == 'Unauthenticated') {
				val tenant = StaticValueInferrer.infer(auth.properties.get('tenant'), []);
				val deviceId = StaticValueInferrer.infer(auth.properties.get('deviceId'), []);
				return '''«instance.instanceOf.name»/«tenant»/«deviceId»''';
			}
		}
		
		super.getTopicName(instance)
	}
	
	override protected getQosLevel(SignalInstance instance) {
		if(instance.instanceOf.name == 'event') {
			return 1;
		}
		
		return super.getQosLevel(instance);
	}
	
	override protected isLogin(SumTypeRepr repr) {
		return repr.name == "Authenticated";
	}
	
}