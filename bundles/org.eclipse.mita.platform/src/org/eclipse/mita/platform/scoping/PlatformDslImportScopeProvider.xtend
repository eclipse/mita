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

package org.eclipse.mita.platform.scoping

import com.google.inject.Inject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.mwe.ResourceDescriptionsProvider
import org.eclipse.xtext.scoping.impl.ImportedNamespaceAwareLocalScopeProvider
import org.eclipse.xtext.scoping.impl.MultimapBasedSelectable
import org.eclipse.xtext.resource.IContainer

import static extension org.eclipse.mita.base.util.BaseUtils.force;

class PlatformDslImportScopeProvider extends ImportedNamespaceAwareLocalScopeProvider {
	@Inject
	ResourceDescriptionsProvider resourceDescriptionsProvider;
	@Inject
	IContainer.Manager containerManager;
	
	override protected getImplicitImports(boolean ignoreCase) {
		return (
			super.getImplicitImports(ignoreCase) 
			+ #[createImportedNamespaceResolver("stdlib.*", ignoreCase)]
		).toList()
	}
	
	override protected internalGetAllDescriptions(Resource resource) {
		val resourceDescriptions = resourceDescriptionsProvider.get(resource.resourceSet);
		val thisResourceDescription = resourceDescriptions.getResourceDescription(resource.URI)
		if (thisResourceDescription === null) {
			return super.internalGetAllDescriptions(resource);
		}
		val visibleContainers = containerManager.getVisibleContainers(thisResourceDescription, resourceDescriptions);
		val exportedObjects = visibleContainers.map[x|x.exportedObjects].flatten().force();
		return new MultimapBasedSelectable(exportedObjects);
	}
	
}