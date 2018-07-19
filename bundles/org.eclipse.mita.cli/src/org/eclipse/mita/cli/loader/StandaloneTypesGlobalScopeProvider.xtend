/********************************************************************************
 * Copyright (c) 2018 TypeFox GmbH.
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

package org.eclipse.mita.cli.loader

import com.google.common.collect.Lists
import com.google.inject.Inject
import java.util.HashSet
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EReference
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.scoping.ILibraryProvider
import org.eclipse.mita.base.scoping.TypesGlobalScopeProvider
import org.eclipse.xtext.resource.IResourceServiceProvider
import org.eclipse.xtext.scoping.Scopes
import org.eclipse.xtext.scoping.impl.SimpleScope

class StandaloneTypesGlobalScopeProvider extends TypesGlobalScopeProvider {
	
	@Inject
	private IResourceServiceProvider.Registry serviceProviderRegistry;
	
	@Inject
	private ILibraryProvider libraryProvider
	
	override protected getLibraryScope(Resource context, EReference reference) {
		val result = new HashSet();
		for(URI uri : libraryProvider.libraries) {
			result.add(uri);
		}
//		for(URI uri : libraryProvider.getImportedLibraries(context)) {
//			result.add(uri);
//		}
		
		val objDescriptions = (libraryProvider.libraries).flatMap[
			val resource = context.resourceSet.getResource(it, true);
			val resourceServiceProvider = serviceProviderRegistry.getResourceServiceProvider(it);
			
			if (resourceServiceProvider === null) {
				Scopes.scopedElementsFor(Lists.newArrayList(resource.getAllContents()));
			} else {
				val resourceDescription = resourceServiceProvider.getResourceDescriptionManager().getResourceDescription(resource);
				resourceDescription.getExportedObjects();
			}
		];
		return new SimpleScope(objDescriptions);
	}
	
}