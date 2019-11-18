package org.eclipse.mita.platform.unittest

import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.MainSystemResourceGenerator

class UnittestPlatformGenerator extends MainSystemResourceGenerator {
	override long getEventHandlerPayloadQueueSize(EventHandlerDeclaration handler) {
		return 10;
	}

	override CodeFragment generateSetup() {
		return codeFragmentProvider.create();
	}

	override CodeFragment generateEnable() {
		return codeFragmentProvider.create();
	}
}
