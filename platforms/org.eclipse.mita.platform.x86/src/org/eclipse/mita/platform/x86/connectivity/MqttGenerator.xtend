package org.eclipse.mita.platform.x86.connectivity

import com.google.inject.Inject
import java.util.Optional
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.library.stdlib.RingbufferGenerator
import org.eclipse.mita.platform.x86.IMakefileParticipant
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemEventSource
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeWithContext
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.model.ModelUtils

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull;
import org.eclipse.mita.library.stdlib.RingbufferGenerator.PushGenerator
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.program.generator.GeneratorUtils

class MqttGenerator extends AbstractSystemResourceGenerator implements IMakefileParticipant {
	@Inject
	protected extension StatementGenerator;
	
	@Inject
	protected PushGenerator pushGenerator;
	
	@Inject
	protected StdlibTypeRegistry typeRegistry;
	
	@Inject
	protected extension GeneratorUtils;
	
	// returns a char*
	protected def getHandlerTopic(EventHandlerDeclaration handler) {
		val sigInst = handler.event.castOrNull(SystemEventSource)?.signalInstance;
		return '''«sigInst?.name»TopicBuf''';
	}
	
	override generateSetup() {
		return codeFragmentProvider.create('''
			int exception = MQTTClient_create(&client, «setup.getConfigurationItemValue("url").code», «setup.getConfigurationItemValue("clientId").code», MQTTCLIENT_PERSISTENCE_NONE, NULL);
			if(exception != 0) {
				printf("Error in MQTT_Setup: %d\n", exception);
				return exception;
			}
			conn_opts.keepAliveInterval = «setup.getConfigurationItemValueOrDefault("keepAliveInterval").code»;
			conn_opts.cleansession = «setup.getConfigurationItemValueOrDefault("cleanSession").code»;
			MQTTClient_setCallbacks(client, NULL, NULL, messageArrivedCb, NULL);
		''').setPreamble('''
			MQTTClient client;
			MQTTClient_connectOptions conn_opts = MQTTClient_connectOptions_initializer;
			MQTTClient_deliveryToken token;
			
			«FOR signalInstance: setup.signalInstances»
				char «signalInstance.name»TopicBuf[] = «ModelUtils.getArgumentValue(signalInstance, "name").code»;
			«ENDFOR»
			«FOR handler: eventHandler»
				extern ringbuffer_array_char rb_«handler.handlerName»;
			«ENDFOR»
			
			int messageArrivedCb(void* context, char* topicName, int topicLen, MQTTClient_message* message) {
				array_char msg = (array_char) {
					.data = message->payload,
					.capacity = message->payloadlen,
					.length = message->payloadlen
				};
				int exception = 0;
				if(topicLen == 0) {
					topicLen = strlen(topicName);
				}
				«FOR handler: eventHandler»
					if(exception == 0 && strlen(«getHandlerTopic(handler)») == topicLen && 0 == memcmp(topicName, «getHandlerTopic(handler)», topicLen)) {
						«pushGenerator.generate(
							handler,
							new CodeWithContext(RingbufferGenerator.wrapInRingbuffer(typeRegistry, handler, BaseUtils.getType(handler.event.castOrNull(SystemEventSource))), Optional.empty, codeFragmentProvider.create('''rb_«handler.handlerName»''')),
							codeFragmentProvider.create('''msg''')
						)»
						«handler.handlerName»_flag = 1;
					}
				«ENDFOR»
				MQTTClient_free(topicName);
				return exception;
			}
		''').addHeader("MQTTClient.h", false)
			.addHeader("MitaEvents.h", false)
			.addHeader("string.h", true)
	}
	
	override generateEnable() {
		return codeFragmentProvider.create('''
			int exception;
			exception = MQTTClient_connect(client, &conn_opts);
			if(exception != MQTTCLIENT_SUCCESS) {
				return exception;
			}
			«FOR signalInstance: setup.signalInstances»
			exception = MQTTClient_subscribe(client, «signalInstance.name»TopicBuf, «ModelUtils.getArgumentValue(signalInstance, "qos").code»);
			if(exception != MQTTCLIENT_SUCCESS) {
				return exception;
			}
			«ENDFOR»
		''').addHeader("MQTTClient.h", false)
	}
	
	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		return CodeFragment.EMPTY;
	}
	
	override generateSignalInstanceSetter(SignalInstance signalInstance, String valueVariableName) {
		return codeFragmentProvider.create('''
			uint32_t exception = 0;
			
			MQTTClient_message pubmsg = MQTTClient_message_initializer;
			pubmsg.payload = «valueVariableName»->data;
			pubmsg.payloadlen = «valueVariableName»->length;
			pubmsg.qos = «ModelUtils.getArgumentValue(signalInstance, "qos").code»;
			pubmsg.retained = 0;
			MQTTClient_publishMessage(client, «signalInstance.name»TopicBuf, &pubmsg, &token);
			exception = MQTTClient_waitForCompletion(client, token, 10000L);
			return exception;
		''');
	}
	
	override getLibraries() {
		return #["paho-mqtt3c"]
	}
	
}
