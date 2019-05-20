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

import com.google.inject.Inject
import org.eclipse.core.resources.IMarker
import org.eclipse.core.resources.IResource
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.core.runtime.Path
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.diagnostics.Severity
import org.eclipse.xtext.generator.IShouldGenerate
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.validation.CheckMode
import org.eclipse.xtext.validation.IResourceValidator
import org.eclipse.xtext.workspace.ProjectConfigAdapter

class ProjectErrorShouldGenerate implements IShouldGenerate {

	@Inject IResourceValidator validator

	override shouldGenerate(Resource resource, CancelIndicator cancelIndicator) {
		val uri = resource.URI
		if (uri === null || !uri.isPlatformResource)
			return false
		val member = ResourcesPlugin.workspace.root.findMember(new Path(uri.toPlatformString(true)))
		if (member !== null && member.type === IResource.FILE) {
			val projectConfig = ProjectConfigAdapter.findInEmfObject(resource.resourceSet)?.projectConfig
			val project = member.project;
			
			if (project.name == projectConfig?.name) {
				val allMakers = project.findMarkers(IMarker.PROBLEM, true, IResource.DEPTH_INFINITE);
				if(allMakers.exists[ it.getAttribute(IMarker.SEVERITY) == IMarker.SEVERITY_ERROR && it.resource.name.toLowerCase.endsWith(MitaBaseResource.PROGRAM_EXT) ]) {
					return false;					
				}
			}
		}

		return resource.isValid(cancelIndicator);
	}

	def protected isValid(Resource resource, CancelIndicator cancelIndicator) {
		val issues = validator.validate(resource, CheckMode.ALL, cancelIndicator)
		if (issues.exists[severity == Severity.ERROR])
			return false;
		return true;
	}
}
