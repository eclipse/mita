package org.eclipse.mita.platform.x86.platform

import org.eclipse.mita.program.generator.MainSystemResourceGenerator
import org.eclipse.mita.program.EventHandlerDeclaration

class X86PlatformGenerator extends MainSystemResourceGenerator {
	
	override getEventHandlerPayloadQueueSize(EventHandlerDeclaration handler) {
		return 2L;
	}
	
	override generateSetup() {
		return codeFragmentProvider.create();
	}
	
	override generateEnable() {
		return codeFragmentProvider.create();
	}
	
}