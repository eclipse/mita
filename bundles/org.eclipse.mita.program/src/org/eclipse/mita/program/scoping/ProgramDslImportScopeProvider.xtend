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

package org.eclipse.mita.program.scoping

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.scoping.BaseImportScopeProvider
import org.eclipse.mita.base.types.ImportStatement
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.PackageAssociation
import org.eclipse.xtext.mwe.ResourceDescriptionsProvider
import org.eclipse.xtext.resource.IContainer
import org.eclipse.xtext.scoping.IScope
import org.eclipse.xtext.scoping.Scopes
import org.eclipse.xtext.scoping.impl.MultimapBasedSelectable

import static extension org.eclipse.mita.base.util.BaseUtils.force

class ProgramDslImportScopeProvider extends BaseImportScopeProvider {

	@Inject
	ResourceDescriptionsProvider resourceDescriptionsProvider;
	@Inject
	IContainer.Manager containerManager;
	
	public static val IMPLICIT_IMPORTS = #["stdlib.*"]

	override protected String getImportedNamespace(EObject object) {
		// Mita imports are always wildcard imports. We do not support fully qualified references. 
		if (object instanceof ImportStatement) {
			return object.importedNamespace + ".*"
		}
		return super.getImportedNamespace(object)
	}

	override protected getImplicitImports(boolean ignoreCase) {
		IMPLICIT_IMPORTS.map[createImportedNamespaceResolver(it, ignoreCase)].toList
	}

	override protected getLocalElementsScope(IScope parent, EObject context, EReference reference) {
		if(context instanceof Operation) {
			if(reference == ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference) {
				return Scopes.scopeFor(context.parameters, parent);
			}
		}

		return super.getLocalElementsScope(parent, context, reference)
	}

	// Adds the ownPackage as import
	override protected internalGetImportedNamespaceResolvers(EObject context, boolean ignoreCase) {
		val superImports = super.internalGetImportedNamespaceResolvers(context, ignoreCase)
		if (context instanceof PackageAssociation) {
			superImports += createImportedNamespaceResolver((context as PackageAssociation).name + ".*", ignoreCase)
		}
		return superImports
	}

	// Filter all objects that are not marked as 'exported'
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
