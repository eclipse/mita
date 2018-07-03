package org.eclipse.mita.platform.arduino.uno.platform

import org.eclipse.mita.program.generator.EmptyPlatformGeneratorModule

class ArduinoUnoPlatformGeneratorModule extends EmptyPlatformGeneratorModule {

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
