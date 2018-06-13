/********************************************************************************
 * Copyright (c) 2018 itemis AG.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    itemis AG - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/
 
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
