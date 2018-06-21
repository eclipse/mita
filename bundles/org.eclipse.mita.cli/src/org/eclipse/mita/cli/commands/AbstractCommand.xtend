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
import org.apache.commons.cli.Options

/**
 * @author Christian Weichel
 */
abstract class AbstractCommand {
	protected String commandName;
	protected CommandLine commandLine;
	
	def Options getOptions() {
		return null
	}
	
	def void run()
	
	def boolean init(String commandName, CommandLine commandLine) {
		this.commandName = commandName;
		this.commandLine = commandLine;
		return true;
	}
	
}
