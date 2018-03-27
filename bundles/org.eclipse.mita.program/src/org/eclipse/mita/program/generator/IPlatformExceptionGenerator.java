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

import org.yakindu.base.types.Type;

public interface IPlatformExceptionGenerator {

	/**
	 * Generates valid C code which generates a value uniquely identifying this
	 * exception type.
	 * 
	 * @param program
	 *            The program to generate the exception code for.
	 * @param exception
	 *            The exception whose code to generate.
	 * @return the generate code
	 */
	public CodeFragment generateExceptionCodeFor(CompilationContext context, Type exception);

	/**
	 * Generates C code which raises the exception in exceptionVariableName
	 * system-wide. If the exception stored in that variable is NO_EXCEPTION,
	 * nothing ought to happen.
	 * 
	 * @param program
	 *            the program that caused the exception
	 * @param exceptionVariableName
	 *            the name of the variable the exception is stored in
	 * @return the generated code
	 */
	public CodeFragment generateRaiseException(CompilationContext context, String exceptionVariableName);

	/**
	 * Produces a single C type statement identifying the exception type used by
	 * this platform.
	 * 
	 * @return the exception type
	 */
	public CodeFragment getExceptionType();

	/**
	 * Produces a single C statement representing a no-exception condition.
	 * 
	 * @return the generated code
	 */
	public CodeFragment getNoExceptionStatement();

	public class NullImpl implements IPlatformExceptionGenerator {

		@Override
		public CodeFragment generateExceptionCodeFor(CompilationContext context, Type exception) {
			return CodeFragment.EMPTY;
		}

		@Override
		public CodeFragment generateRaiseException(CompilationContext context, String exceptionVariableName) {
			return CodeFragment.EMPTY;
		}

		@Override
		public CodeFragment getExceptionType() {
			return CodeFragment.EMPTY;
		}

		@Override
		public CodeFragment getNoExceptionStatement() {
			return CodeFragment.EMPTY;
		}

	}
}