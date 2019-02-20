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

package org.eclipse.mita.program.model

import com.google.inject.Inject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.library.^extension.LibraryExtensions
import org.eclipse.xtext.resource.IContainer
import org.eclipse.xtext.resource.IResourceDescriptionsProvider
import static extension org.eclipse.mita.base.util.BaseUtils.force

class ImportHelper {

	@Inject extension IResourceDescriptionsProvider
	@Inject extension IContainer.Manager

	def getVisiblePackages(Resource resource) {
		// Add Packages from Index
		val index = resource.resourceSet.getResourceDescriptions
		val inIndexPackages = index.exportedObjects.filter[ TypesPackage.Literals.PACKAGE_ASSOCIATION.isSuperTypeOf(it.EClass) ].force
		
		val resDesc = index.getResourceDescription(resource.URI)
		val visibleContainers = getVisibleContainers(resDesc, index)
		val visiblePackages = (
			inIndexPackages + 
			visibleContainers
				.map [ it.getExportedObjectsByType(TypesPackage.Literals.PACKAGE_ASSOCIATION) ]
				.flatten
			).map[name.toString]
			.toList
		// Add Packages from Libraries contributed via extensions
		visiblePackages += LibraryExtensions.availablePlatforms.map[ id ]
		return visiblePackages.toSet
	}

}
