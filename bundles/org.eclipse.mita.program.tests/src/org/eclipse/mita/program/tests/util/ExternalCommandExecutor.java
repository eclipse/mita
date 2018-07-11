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
package org.eclipse.mita.program.tests.util;

import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.Reader;
import java.util.List;

public class ExternalCommandExecutor {

	/**
	 * Executes given commands in given working directory. Reads error stream and
	 * throws RuntimeException in case of error.
	 */
	public void execute(List<String> command, File workingDirectory) throws Exception {
		ProcessBuilder processBuilder = new ProcessBuilder(command).directory(workingDirectory);
		Process process = processBuilder.redirectErrorStream(true).start();
		String message = readProcessInputStream(process);

		boolean wait = true;
		int exitCode = 0;

		do {
			wait = false;

			// waiting for the processes termination
			try {
				process.waitFor();
			} catch (InterruptedException e) {
				// we ignore if waiting was interrupted ...
			}

			// if we get an exit code then we know that the process is finished
			try {
				exitCode = process.exitValue();
			} catch (IllegalThreadStateException e) {
				wait = true; // if we get an exception then the process has not finished
			}
		} while (wait);

		if (exitCode != 0) {

			throw new RuntimeException("Execution of command '" + String.join(" ", command) + "' failed (exit status "
					+ process.exitValue() + "):\n" + message);
		}
	}

	private String readProcessInputStream(Process process) throws IOException {
		Reader reader = new InputStreamReader(process.getInputStream());
		char[] buffer = new char[4096];
		int count;
		StringBuilder message = new StringBuilder();
		while ((count = reader.read(buffer)) != -1) {
			message.append(buffer, 0, count);
		}
		return message.toString();
	}
}
