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

import java.lang.reflect.InvocationTargetException
import org.eclipse.cdt.core.CProjectNature
import org.eclipse.core.resources.IProject
import org.eclipse.core.resources.IWorkspace
import org.eclipse.core.resources.IWorkspaceRunnable
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.core.runtime.CoreException
import org.eclipse.core.runtime.IProgressMonitor
import org.eclipse.core.runtime.NullProgressMonitor
import org.eclipse.ui.PlatformUI
import org.eclipse.ui.actions.WorkspaceModifyOperation
import org.eclipse.xtext.ui.XtextProjectHelper

/**
 * Creates and holds an empty project with Xtext nature setup for testing purposes
 */
class TestProjectHelper {
	
	public val String testProjectName = "unittestprj"
	
	def getTestProject() {
		return ResourcesPlugin.workspace.root.getProject(testProjectName);
	}
	
	def createEmptyTestProject() {
		val project = testProject;
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
	
	protected def IProject createProject(String name) throws CoreException {
		val workspace = ResourcesPlugin.getWorkspace();
		disableAutoBuild(workspace);

		workspace.run(new IWorkspaceRunnable() {
			
			override run(IProgressMonitor monitor) throws CoreException {
				val root = workspace.getRoot();
				val project = root.getProject(name);
				if (!project.exists()) {
					project.create(monitor);
					project.open(monitor);
					CProjectNature.addNature(project, XtextProjectHelper.NATURE_ID, monitor);
				} else {
					if (!project.isOpen) {
						project.open(monitor);
					}
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
