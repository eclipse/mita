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

package org.eclipse.mita.platform.x86.platform

import com.google.inject.Inject
import java.util.List
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.IPlatformMakefileGenerator

class MakefileGenerator implements IPlatformMakefileGenerator {
	@Inject
	private CodeFragmentProvider codeFragmentProvider 
	
	override generateMakefile(Iterable<Program> program, List<String> sourceFiles) {
		return codeFragmentProvider.create('''
		export CC=gcc
		export CCFLAGS=-Wall -std=c99 -D_POSIX_C_SOURCE=199309L -D_DEFAULT_SOURCE -g
		export BUILDDIR=./build
		export SOURCE_INCLUDES = -I. -I./base
		export SOURCE_DIR=.
		export SOURCE_FILES = \
			«sourceFiles.filter[x | x.endsWith('.c') ].map[x | '''$(SOURCE_DIR)/«x»'''].join(' \\\n')»
		
		.PHONY: clean build
		
		all:
			mkdir -p $(BUILDDIR)
			$(CC) $(CCFLAGS) $(SOURCE_INCLUDES) -o$(BUILDDIR)/app $(SOURCE_FILES)
		
		clean:
			rm $(BUILDDIR)/*
	''')
	}
}