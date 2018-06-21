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

package org.eclipse.mita.cli.commands

import com.google.inject.Guice
import com.google.inject.util.Modules
import java.io.FileOutputStream
import java.io.PrintWriter
import java.net.InetSocketAddress
import java.nio.channels.AsynchronousServerSocketChannel
import java.nio.channels.Channels
import org.apache.commons.cli.Options
import org.eclipse.mita.cli.loader.StandaloneModule
import org.eclipse.mita.cli.loader.StandanloneLangServerModule
import org.eclipse.mita.program.ProgramDslRuntimeModule
import org.eclipse.xtext.ide.server.LaunchArgs
import org.eclipse.xtext.ide.server.ServerLauncher
import org.eclipse.xtext.ide.server.ServerModule
import org.eclipse.xtext.resource.IResourceFactory
import org.eclipse.xtext.resource.IResourceServiceProvider

class LanguageServerCommand extends AbstractCommand {
	
	override getOptions() {
		val result = new Options();
		result.addOption('t', 'trace', false, 'Enable tracing of incoming/outgoing messages');
		result.addOption('s', 'should-validate', false, 'Enable validation of incoming messages');
		result.addOption('d', 'debug', false, 'Log standard out for debugging');
		return result;
	}
	
	override run() {
		val programModule = Modules.override(new ProgramDslRuntimeModule()).with(new StandaloneModule(), Modules.override(new ServerModule()).with(new StandanloneLangServerModule()));
		val programInjector = Guice.createInjector(programModule);
		
		val languagesRegistry = programInjector.getInstance(IResourceServiceProvider.Registry);
		languagesRegistry.extensionToFactoryMap.put("mita", programInjector.getInstance(IResourceFactory));
		
		val serverSocket = AsynchronousServerSocketChannel.open.bind(new InetSocketAddress("localhost", 5007))
		println("Language server started");		

		while (true) {
			val socketChannel = serverSocket.accept.get
			val in = Channels.newInputStream(socketChannel)
			val out = Channels.newOutputStream(socketChannel)
			
			val launchArgs = new LaunchArgs
			launchArgs.in = in
			launchArgs.out = out
			if(this.commandLine.hasOption('t')) {
				launchArgs.trace = new PrintWriter(new FileOutputStream("mita-language-server-trace.log"));
			}
			launchArgs.validate = commandLine.hasOption('s');
			
			val launcher = programInjector.getInstance(ServerLauncher);
			launcher.start(launchArgs);
		}		
	}
	
}