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

import java.util.List;

import org.eclipse.mita.program.Program;

public interface IPlatformMakefileGenerator {

	/**
	 * 
	 * @param program
	 *            the program we're generating a makefile for
	 * @param sourceFiles
	 *            the source files we need to compile
	 * @return the makefile content
	 */
	public CodeFragment generateMakefile(Iterable<Program> compilationUnits, List<String> sourceFiles);

	public class NullImpl implements IPlatformMakefileGenerator {

		@Override
		public CodeFragment generateMakefile(Iterable<Program> compilationUnits, List<String> sourceFiles) {
			return CodeFragment.EMPTY;
		}

	}
}