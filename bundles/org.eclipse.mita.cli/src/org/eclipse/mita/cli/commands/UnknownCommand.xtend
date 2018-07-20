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

import org.apache.commons.cli.CommandLine

class UnknownCommand extends AbstractCommand {
	
	override init(String commandName, CommandLine commandLine) {
		super.init(commandName, commandLine);
		System.err.println("unknown command: " + commandName);		
		return false;
	}
	
	override run() {
		throw new UnsupportedOperationException("This command should never be executed")
	}
	
}