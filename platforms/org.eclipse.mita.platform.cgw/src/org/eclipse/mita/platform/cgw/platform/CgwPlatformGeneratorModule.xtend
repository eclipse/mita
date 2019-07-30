/********************************************************************************
 * Copyright (c) 2019 Robert Bosch GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/
 
package org.eclipse.mita.platform.cgw.platform

import org.eclipse.mita.program.generator.EmptyPlatformGeneratorModule

class CgwPlatformGeneratorModule extends EmptyPlatformGeneratorModule {

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
	
	override bindPlatformBuildSystemGenerator() {
		MesonGenerator
	}
	
	override bindIPlatformLoggingGenerator() {
		LoggingGenerator
	}

}
