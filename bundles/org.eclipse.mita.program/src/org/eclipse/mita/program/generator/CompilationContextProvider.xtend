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

package org.eclipse.mita.program.generator

import org.eclipse.mita.program.Program
import com.google.inject.Inject
import com.google.inject.Provider

class CompilationContextProvider {
	@Inject Provider<CompilationContext> delegate;
	
	public def CompilationContext get(Iterable<Program> compilationUnits, Iterable<Program> stdLib) {
		val cc = delegate.get();
		cc.init(compilationUnits, stdLib);
		return cc;
	}
}