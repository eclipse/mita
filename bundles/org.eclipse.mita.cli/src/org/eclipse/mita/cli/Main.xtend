/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - Initial design and API
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/
package org.eclipse.mita.cli

import org.apache.commons.cli.GnuParser
import org.eclipse.core.runtime.Platform
import org.eclipse.equinox.app.IApplication
import org.eclipse.equinox.app.IApplicationContext
import org.eclipse.mita.cli.commands.CompilerCommand
import org.eclipse.mita.cli.commands.UnknownCommand
import org.eclipse.mita.program.ui.internal.ProgramActivator

class Main implements IApplication {

	override start(IApplicationContext context) throws Exception {
		val args = Platform.applicationArgs;
		if(args.length < 2) {
			println("usage: mita <compile|help> [workspacePath]");
			return null;
		}
		
		val commandName = args.get(0);
		val projectPath = args.get(1);
		val command = if(commandName == 'compile') {
			new CompilerCommand();
		} else {
			new UnknownCommand();
		}
		
		val commandOptions = command.options;
		val commandLine = if(commandOptions !== null) {
			val parser = new GnuParser();
			parser.parse(commandOptions, args.subList(2, args.length));
		} else {
			null
		}
		
		val injector = ProgramActivator.instance.getInjector(ProgramActivator.ORG_ECLIPSE_MITA_PROGRAM_PROGRAMDSL);
		injector.injectMembers(this);
		injector.injectMembers(command);
		
		val execute = command.init(commandName, commandLine);
		if(execute) {
			command.run(projectPath);
		}
		
		return null;
	}
	
	override stop() {
	}
	
}