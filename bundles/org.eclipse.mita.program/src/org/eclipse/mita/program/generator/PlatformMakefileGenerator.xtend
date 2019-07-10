/** 
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 * Contributors:
 * Bosch Connected Devices and Solutions GmbH - initial contribution
 * SPDX-License-Identifier: EPL-2.0
 */
package org.eclipse.mita.program.generator

import com.google.inject.Inject
import java.util.List
import org.eclipse.xtext.generator.IFileSystemAccess2

abstract class PlatformMakefileGenerator extends PlatformBuildSystemGenerator {
	@Inject
	protected extension ProgramDslTraceExtensions;
	@Inject
	protected CodeFragmentProvider codeFragmentProvider 
	
	/** 
	 * @param programthe program we're generating a makefile for
	 * @param sourceFilesthe source files we need to compile
	 * @return the makefile content
	 */
	def CodeFragment generateMakefile(CompilationContext context, List<String> sourceFiles)

	override void generateFiles(IFileSystemAccess2 fsa, CompilationContext context, List<String> sourceFiles) {
		val codefragment = generateMakefile(context, sourceFiles)
		if(codefragment !== null && codefragment != CodeFragment.EMPTY) {
			val root = CodeFragment.cleanNullChildren(codefragment);
			fsa.generateTracedFile('Makefile', root);		
		}
	}
	
	
	static class NullImpl extends PlatformMakefileGenerator {
		override CodeFragment generateMakefile(CompilationContext context, List<String> sourceFiles) {
			return CodeFragment.EMPTY 
		}
	}
}
