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
package org.eclipse.mita.compiler

import com.google.inject.Inject
import java.io.File
import org.eclipse.core.resources.IFile
import org.eclipse.core.resources.IProject
import org.eclipse.core.resources.IProjectDescription
import org.eclipse.core.resources.IWorkspaceRoot
import org.eclipse.core.resources.IncrementalProjectBuilder
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.core.runtime.NullProgressMonitor
import org.eclipse.core.runtime.Path
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.equinox.app.IApplication
import org.eclipse.equinox.app.IApplicationContext
import org.eclipse.mita.platform.PlatformDSLStandaloneSetup
import org.eclipse.mita.program.ProgramDslStandaloneSetup
import org.eclipse.mita.program.generator.ProgramDslGenerator
import org.eclipse.ui.dialogs.IOverwriteQuery
import org.eclipse.ui.wizards.datatransfer.FileSystemStructureProvider
import org.eclipse.ui.wizards.datatransfer.ImportOperation
import org.eclipse.xtext.generator.GeneratorContext
import org.eclipse.xtext.generator.JavaIoFileSystemAccess
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.validation.CheckMode
import org.eclipse.xtext.validation.IResourceValidator
import org.eclipse.xtext.generator.GeneratorDelegate

class Main implements IApplication {
	
	@Inject ProgramDslGenerator programDslGenerator
	
	
	override start(IApplicationContext context) throws Exception {
		val args = context.arguments.get("application.args") as String[];
		if(args.length < 1) {
			println("Need at least one arg: project path");
			return null;
		}
		val projectPath = args.get(0);
		
		val workspace = ResourcesPlugin.getWorkspace();
		val IWorkspaceRoot root = workspace.getRoot();
		
		// import project into workspace
		val IOverwriteQuery overwriteQuery = new IOverwriteQuery() {
		        override queryOverwrite(String file) { return ALL; }
		};
		
		val IProjectDescription description = ResourcesPlugin.getWorkspace().loadProjectDescription(new Path(projectPath + "/.project"));
		val IProject project = root.getProject(description.getName());
		
		val ImportOperation importOperation = new ImportOperation(project.getFullPath(), new File(projectPath), FileSystemStructureProvider.INSTANCE, overwriteQuery);
		importOperation.setCreateContainerStructure(false);
		importOperation.run(new NullProgressMonitor());
		
		
		// start plugins --> program and platform parsers need to register themselves		
		val pdsli = new ProgramDslStandaloneSetup().createInjectorAndDoEMFRegistration()
		val set = pdsli.getInstance(ResourceSet);
		
		val plati = new PlatformDSLStandaloneSetup().createInjectorAndDoEMFRegistration()
		
		// output to original project folder subdir
		val fileAccess = pdsli.getInstance(JavaIoFileSystemAccess)
		fileAccess.outputPath = projectPath + '/src-gen/'
		
		// generate code for all .mita files
		project.members.filter(IFile).filter[it.name.endsWith(".mita")].forEach[ mitaFile |
			// file to URI
			// https://wiki.eclipse.org/EMF/FAQ#How_do_I_map_between_an_EMF_Resource_and_an_Eclipse_IFile.3F
			val uri = URI.createPlatformResourceURI(mitaFile.fullPath.toString, true);
			// load and parse
			val res = set.getResource(uri, true);
			// check for issues
			val validator = pdsli.getInstance(IResourceValidator);
			val issues = validator.validate(res, CheckMode.ALL, CancelIndicator.NullImpl)
			if (!issues.empty) {
				issues.forEach[System.err.println(it)]
				return
			}
			
			val generatorContext = new GeneratorContext => [
				cancelIndicator = CancelIndicator.NullImpl
			]
			// get generator from programDsl
			val generator = pdsli.getInstance(GeneratorDelegate)
			// generate
			generator.generate(res, fileAccess, generatorContext)
		]
		
		return null;
	}
	
	override stop() {
	}
	
}