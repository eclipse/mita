package org.eclipse.mita.platform.arduinouno.platform

import org.eclipse.mita.program.generator.EmptyPlatformGeneratorModule

class ArduinoPlatformGeneratorModule extends EmptyPlatformGeneratorModule {

	override bindIPlatformEventLoopGenerator() {
		EventLoopGenerator
	}

	override bindIPlatformExceptionGenerator() {
		ExceptionGenerator
	}

	override bindIPlatformStartupGenerator() {
		StartupGenerator
	}

	override bindIPlatformTimeGenerator() {
		TimeGenerator
	}

}
