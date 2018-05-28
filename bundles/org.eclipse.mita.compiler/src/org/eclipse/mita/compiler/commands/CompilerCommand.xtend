/********************************************************************************
 * Copyright (c) 2017, 2018 TypeFox GmbH.
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
 
package org.eclipse.mita.compiler.commands

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.mita.program.generator.internal.IGeneratorOnResourceSet
import org.eclipse.xtext.generator.GeneratorContext
import org.eclipse.xtext.generator.IGenerator2
import org.eclipse.xtext.generator.JavaIoFileSystemAccess
import org.eclipse.xtext.util.CancelIndicator

class CompilerCommand extends AbstractCommand {
	@Inject protected Provider<JavaIoFileSystemAccess> fileSystemAccessProvider
	@Inject protected IGenerator2 generator
	
	override doRun() {
		if(resourceSet.resources.empty) {
			System.err.println("Project " + projectPath.toOSString + " is empty. Aborting");
			return;
		}
		
		val fileSystemAccess = fileSystemAccessProvider.get();
		fileSystemAccess.outputPath = projectPath.toOSString + '/src-gen/';
		
		if(generator instanceof IGeneratorOnResourceSet) {
			generator.doGenerate(resourceSet, fileSystemAccess);
		} else {
			val generatorContext = new GeneratorContext => [ cancelIndicator = CancelIndicator.NullImpl ];
			this.resourceSet.resources.forEach[ generator.doGenerate(it, fileSystemAccess, generatorContext) ]			
		}
	}
	
	
}
