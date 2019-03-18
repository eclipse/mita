package org.eclipse.mita.program.generator

import org.eclipse.mita.program.EventHandlerDeclaration

class DefaultMainSystemResourceGenerator extends MainSystemResourceGenerator {
	
	override generateSetup() {
		return codeFragmentProvider.create('''''')
	}
	
	override generateEnable() {
		return codeFragmentProvider.create('''''')
	}
	
	public def getQueueSizeName() {
		return "queueSize";
	}
	
	override getEventHandlerPayloadQueueSize(EventHandlerDeclaration handler) {
		return configuration.getInteger(queueSizeName);
	}	
}
