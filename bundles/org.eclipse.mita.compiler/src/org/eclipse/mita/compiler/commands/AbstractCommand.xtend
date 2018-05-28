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
import java.io.File
import org.apache.commons.cli.CommandLine
import org.apache.commons.cli.Options
import org.eclipse.core.resources.IFile
import org.eclipse.core.resources.IProject
import org.eclipse.core.resources.IProjectDescription
import org.eclipse.core.resources.IWorkspaceRoot
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.core.runtime.IPath
import org.eclipse.core.runtime.NullProgressMonitor
import org.eclipse.core.runtime.Path
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.ui.dialogs.IOverwriteQuery
import org.eclipse.ui.wizards.datatransfer.FileSystemStructureProvider
import org.eclipse.ui.wizards.datatransfer.ImportOperation
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.validation.CheckMode
import org.eclipse.xtext.validation.IResourceValidator
import org.eclipse.core.resources.IResource

/**
 * @author Christian Weichel
 */
abstract class AbstractCommand {
	protected String commandName;
	protected CommandLine commandLine;
	protected IProject project;
	protected ResourceSet resourceSet;
	
	@Inject protected Provider<ResourceSet> resourceSetProvider;
	@Inject protected IResourceValidator resourceValidator;
	
	def Options getOptions() {
		return null
	}
	
	def void run(String projectPath) {
		this.project = createProject(projectPath);
		this.resourceSet = createResourceSet(this.project);
		validateResources(this.resourceSet);
		doRun();
	}
	
	abstract def void doRun()
	
	protected def IPath getProjectPath() {
		return project.location;
	}
	
	def boolean init(String commandName, CommandLine commandLine) {
		this.commandName = commandName;
		this.commandLine = commandLine;
		return true;
	}
	
	protected def createProject(String projectPath) {
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
		project.refreshLocal(IResource.DEPTH_INFINITE, new NullProgressMonitor());
		
		return project;
	}
	
	protected def createResourceSet(IProject project) {
		val result = resourceSetProvider.get();
		val members = project.members;
		members.filter(IFile).filter[
			it.name.endsWith(".mita")
		].forEach[mitaFile |
			// file to URI
			// https://wiki.eclipse.org/EMF/FAQ#How_do_I_map_between_an_EMF_Resource_and_an_Eclipse_IFile.3F
			val fileUri = URI.createPlatformResourceURI(mitaFile.fullPath.toString, true);
			result.getResource(fileUri, true);
		];
		return result;
	}
	
	protected def validateResources(ResourceSet resourceSet) {
		var hasIssues = resourceSet.resources.map[resource|
			// check for issues
			val issues = resourceValidator.validate(resource, CheckMode.ALL, CancelIndicator.NullImpl)
			if (!issues.empty) {
				issues.forEach[ System.err.println(it) ];
				return true;
			} else {
				return false;
			}
		].exists[ it ];

		if(hasIssues) {
			throw new Exception('Errors found in the code. See above.')
		}
	}
	
}
