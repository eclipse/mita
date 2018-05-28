/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - Initial design and API
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/
package org.eclipse.mita.compiler

import com.google.inject.Inject
import com.google.inject.Provider
import java.io.File
import org.eclipse.core.resources.IFile
import org.eclipse.core.resources.IProject
import org.eclipse.core.resources.IProjectDescription
import org.eclipse.core.resources.IWorkspaceRoot
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.core.runtime.NullProgressMonitor
import org.eclipse.core.runtime.Path
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.equinox.app.IApplication
import org.eclipse.equinox.app.IApplicationContext
import org.eclipse.ui.dialogs.IOverwriteQuery
import org.eclipse.ui.wizards.datatransfer.FileSystemStructureProvider
import org.eclipse.ui.wizards.datatransfer.ImportOperation
import org.eclipse.xtext.generator.GeneratorContext
import org.eclipse.xtext.generator.GeneratorDelegate
import org.eclipse.xtext.generator.JavaIoFileSystemAccess
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.validation.CheckMode
import org.eclipse.xtext.validation.IResourceValidator
import org.eclipse.mita.program.ui.internal.ProgramActivator
import org.eclipse.core.runtime.Platform

class Main implements IApplication {

	@Inject Provider<ResourceSet> resourceSetProvider
	
	@Inject Provider<JavaIoFileSystemAccess> fileSystemAccessProvider
	
	@Inject IResourceValidator resourceValidator
	
	@Inject GeneratorDelegate generator
	
	
	override start(IApplicationContext context) throws Exception {
		val args = Platform.applicationArgs;
		if(args.length < 1) {
			println("Need at least one arg: project path");
			return null;
		}
		val projectPath = args.get(0);
		
		ProgramActivator.instance.getInjector(ProgramActivator.ORG_ECLIPSE_MITA_PROGRAM_PROGRAMDSL).injectMembers(this);
		
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
//		val pdsli = new ProgramDslStandaloneSetup().createInjectorAndDoEMFRegistration()
		val set = resourceSetProvider.get();
		
		
		// output to original project folder subdir
		val fileAccess = fileSystemAccessProvider.get();
		fileAccess.outputPath = projectPath + '/src-gen/';
		
		// generate code for all .mita files
		project.members.filter(IFile).filter[it.name.endsWith(".mita")].forEach[ mitaFile |
			// file to URI
			// https://wiki.eclipse.org/EMF/FAQ#How_do_I_map_between_an_EMF_Resource_and_an_Eclipse_IFile.3F
			val uri = URI.createPlatformResourceURI(mitaFile.fullPath.toString, true);
			// load and parse
			val res = set.getResource(uri, true);
			// check for issues
			val issues = resourceValidator.validate(res, CheckMode.ALL, CancelIndicator.NullImpl)
			if (!issues.empty) {
				issues.forEach[System.err.println(it)]
				return
			}
			
			val generatorContext = new GeneratorContext => [
				cancelIndicator = CancelIndicator.NullImpl
			]
			
			generator.generate(res, fileAccess, generatorContext)
		]
		
		return null;
	}
	
	override stop() {
	}
	
}