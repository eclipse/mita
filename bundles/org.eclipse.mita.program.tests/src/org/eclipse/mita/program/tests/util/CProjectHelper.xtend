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

package org.eclipse.mita.program.tests.util

import java.io.IOException
import java.io.InputStream
import java.lang.reflect.InvocationTargetException
import org.eclipse.cdt.core.CCProjectNature
import org.eclipse.cdt.core.CCorePlugin
import org.eclipse.core.resources.IFile
import org.eclipse.core.resources.IProject
import org.eclipse.core.resources.IWorkspace
import org.eclipse.core.resources.IWorkspaceRunnable
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.core.runtime.CoreException
import org.eclipse.core.runtime.FileLocator
import org.eclipse.core.runtime.IPath
import org.eclipse.core.runtime.IProgressMonitor
import org.eclipse.core.runtime.NullProgressMonitor
import org.eclipse.core.runtime.Path
import org.eclipse.core.runtime.SubMonitor
import org.eclipse.ui.PlatformUI
import org.eclipse.ui.actions.WorkspaceModifyOperation
import org.eclipse.xtext.ui.XtextProjectHelper
import org.osgi.framework.Bundle

class CProjectHelper {
	
	public val String testProjectName = "unittestprj"
	
	public def getGenerationProject() {
		return ResourcesPlugin.workspace.root.getProject(testProjectName);
	}
	
	public def createEmptyGenerationProject() {
		val project = generationProject;
		val op = new WorkspaceModifyOperation() {
			override protected execute(IProgressMonitor monitor) throws CoreException, InvocationTargetException, InterruptedException {
				if (project.exists) {
					project.delete(true, true, new NullProgressMonitor());
				}
				createProject(testProjectName);
			}
			
		}
		try {
			PlatformUI.getWorkbench().getProgressService().run(false, true, op);
		} catch (InvocationTargetException e) {
			e.printStackTrace();
		} catch (InterruptedException e) {
			e.printStackTrace();
		}

		return project;
	}
	
	def protected copyFileFromBundleToFolder(Bundle bundle, String sourcePath, String targetPath) {
		copyFileFromBundleToFolder(bundle, new Path(sourcePath), new Path(targetPath));
	}
	
	def protected copyFileFromBundleToFolder(Bundle bundle, IPath sourcePath, IPath targetPath) {
		try {
			val is = FileLocator.openStream(bundle, sourcePath, false);
			createFile(targetPath, is);
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
	}
	
	def protected createFile(IPath path, InputStream source) {
		val file = ResourcesPlugin.getWorkspace().getRoot().getFile(path);
		createFile(file, source);
	}

	def protected createFile(IFile file, InputStream source) {
		try {
			if (file.exists()) {
				file.setContents(source, true, false, new NullProgressMonitor());
			} else {
				file.create(source, true, new NullProgressMonitor());
			}
		} catch (CoreException e) {
			throw new RuntimeException(e);
		}
	}
	
	protected def IProject createProject(String name) throws CoreException {
		val workspace = ResourcesPlugin.getWorkspace();
		disableAutoBuild(workspace);

		workspace.run(new IWorkspaceRunnable() {
			
			override run(IProgressMonitor monitor) throws CoreException {
				val subMonitor = SubMonitor.convert(monitor);
				val root = workspace.getRoot();
				val newProject = root.getProject(name);
				if (!newProject.exists()) {
					val description = workspace.newProjectDescription(newProject.getName());
					val project = CCorePlugin.getDefault().createCProject(description, newProject, subMonitor.newChild(1), name);
					
					
					CCProjectNature.addNature(project, XtextProjectHelper.NATURE_ID, subMonitor.newChild(1));
				}
			}

		}, null);
		return workspace.getRoot().getProject(name);
	}

	protected def void disableAutoBuild(IWorkspace workspace) throws CoreException {
		val description = workspace.getDescription();
		description.setAutoBuilding(false);
		workspace.setDescription(description);
	}
	
}
