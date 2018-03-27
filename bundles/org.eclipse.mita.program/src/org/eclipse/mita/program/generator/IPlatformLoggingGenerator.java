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

import org.eclipse.mita.program.InterpolatedStringExpression;

public interface IPlatformLoggingGenerator {

	/**
	 * The logging levels we support at runtime.
	 */
	static enum LogLevel {
		/**
		 * Debug messages are used to debug the runtime behavior of generated components.
		 * They are unlikely to be of value to regular users of Mita.
		 */
		Debug,
		
		/**
		 * Info level messages inform users about the current operating state. For example if a 
		 * system resource successfully initializes, that is an info statement. 
		 */
		Info,
		
		/**
		 * Warnings messages indicate behavior which is out of the ordinary, yet can be recovered from.
		 * For example, if an action expectedly fails to complete and we will tray again, that's a warning. 
		 */
		Warning,
		
		/**
		 * Errors are all things which prevent the system from operating normally. User intervention is required
		 * to recover from those errors. All uncaught exceptions produce an error message. All system resources
		 * which fail their enable or setup phase produce an error message.
		 */
		Error
	}
	
	/**
	 * Generates a runtime logging statement. The produced CodeFragment must be a valid C statement.
	 * We expect some level of printf-like capability. If that is not available, implementors can fall-back to
	 * the {@link InterpolatedStringExpression} and use the {@link StatementGenerator} to produce the printf code.
	 * 
	 * @param level the level at which we want to log the message
	 * @param pattern a printf style pattern, including the log message itself
	 * @param values valid C expressions constituting the values to fill the pattern
	 * @return a valid C statement which transports the log message to the user.
	 */
	public CodeFragment generateLogStatement(LogLevel level, String pattern, CodeFragment ... values);
	

	public static class NullImpl implements IPlatformLoggingGenerator {

		@Override
		public CodeFragment generateLogStatement(LogLevel level, String pattern, CodeFragment... values) {
			return CodeFragment.EMPTY;
		}
		
	}
	
}
