/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.platform.xdk110.platform

import org.eclipse.mita.program.generator.EmptyPlatformGeneratorModule

class Xdk110PlatformGeneratorModule extends EmptyPlatformGeneratorModule {
	
	override bindIPlatformEventLoopGenerator() {
		EventLoopGenerator
	}
	
	override bindIPlatformExceptionGenerator() {
		ExceptionGenerator
	}
	
	override bindIPlatformMakefileGenerator() {
		MakefileGenerator
	}
	
	override bindIPlatformStartupGenerator() {
		StartupGenerator
	}
	
	override bindIPlatformTimeGenerator() {
		TimeGenerator
	}
	
	override bindIPlatformLoggingGenerator() {
		LoggingGenerator
	}
	
	override bindMainSystemResourceGenerator() {
		Xdk110PlatformGenerator
	}
	
}