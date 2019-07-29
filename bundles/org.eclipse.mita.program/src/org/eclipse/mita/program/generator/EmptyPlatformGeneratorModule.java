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

package org.eclipse.mita.program.generator;

import org.eclipse.xtext.service.AbstractGenericModule;

public class EmptyPlatformGeneratorModule extends AbstractGenericModule {

	public Class<? extends IPlatformEventLoopGenerator> bindIPlatformEventLoopGenerator() {
		return IPlatformEventLoopGenerator.NullImpl.class;
	}

	public Class<? extends IPlatformExceptionGenerator> bindIPlatformExceptionGenerator() {
		return IPlatformExceptionGenerator.NullImpl.class;
	}

	public Class<? extends IPlatformMakefileGenerator> bindIPlatformMakefileGenerator() {
		return IPlatformMakefileGenerator.NullImpl.class;
	}

	public Class<? extends IPlatformStartupGenerator> bindIPlatformStartupGenerator() {
		return IPlatformStartupGenerator.NullImpl.class;
	}

	public Class<? extends IPlatformTimeGenerator> bindIPlatformTimeGenerator() {
		return IPlatformTimeGenerator.NullImpl.class;
	}
	
	public Class<? extends IPlatformLoggingGenerator> bindIPlatformLoggingGenerator() {
		return IPlatformLoggingGenerator.NullImpl.class;
	}

	public Class<? extends MainSystemResourceGenerator> bindMainSystemResourceGenerator() {
		return DefaultMainSystemResourceGenerator.class;
	}
}
