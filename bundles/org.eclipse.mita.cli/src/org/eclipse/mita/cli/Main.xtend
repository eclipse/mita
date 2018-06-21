/********************************************************************************
 * Copyright (c) 2018 TypeFox GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.cli

import com.google.inject.Guice
import com.google.inject.util.Modules
import org.apache.commons.cli.GnuParser
import org.apache.commons.cli.HelpFormatter
import org.apache.commons.cli.MissingOptionException
import org.apache.commons.cli.Options
import org.eclipse.mita.base.TypeDslStandaloneSetup
import org.eclipse.mita.cli.commands.CompileCommand
import org.eclipse.mita.cli.commands.UnknownCommand
import org.eclipse.mita.cli.loader.StandaloneModule
import org.eclipse.mita.platform.PlatformDSLRuntimeModule
import org.eclipse.mita.platform.PlatformDSLStandaloneSetup
import org.eclipse.mita.program.ProgramDslRuntimeModule
import org.eclipse.mita.program.ProgramDslStandaloneSetup
import org.eclipse.mita.cli.commands.LanguageServerCommand

class Main {
	protected static val commands = #{
		'compile' -> CompileCommand,
		'language-server' -> LanguageServerCommand,
		'' -> UnknownCommand
	}

	def static void main(String[] args) {
		if(args.length < 1) {
			printUsage();
			return;
		}
		
		val commandName = args.get(0);
		val commandClass = commands.get(commandName) ?: commands.get('');
		val command = commandClass.newInstance;
		
		val commandOptions = command.options;
		val commandLine = if(commandOptions !== null) {
			val parser = new GnuParser();
			try {
				parser.parse(commandOptions, args.subList(1, args.length));
			} catch(MissingOptionException e) {
				System.err.println(e.message);
				printUsage(commandName, commandOptions);
				return;
			}
		} else {
			null
		}
		
		TypeDslStandaloneSetup.doSetup();
		
		val injector = Guice.createInjector(Modules.override(new ProgramDslRuntimeModule()).with(new StandaloneModule()));
		new ProgramDslStandaloneSetup().register(injector);
		
		val platformInjector = Guice.createInjector(Modules.override(new PlatformDSLRuntimeModule()).with(new StandaloneModule()));
		new PlatformDSLStandaloneSetup().register(platformInjector);
		
		injector.injectMembers(command);
		
		println("Warning: mita CLI tooling is still experimental. Here be dragons.")
		val execute = command.init(commandName, commandLine);
		if(execute) {
			command.run();
		}
	}
	
	static def printUsage() {
		println('''
		usage: mita [command]
		where command is: «commands.keySet.filter[ !it.empty ].join(', ')»''');
	}
	
	static def printUsage(String command, Options options) {
		val formatter = new HelpFormatter();
		formatter.printHelp( "mita " + command, options );
	}
}