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

package org.eclipse.mita.base.scoping;

import java.util.ArrayList;
import java.util.List;

import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EReference;
import org.eclipse.emf.ecore.EStructuralFeature;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.mita.base.types.TypesPackage;
import org.eclipse.mita.base.types.typesystem.ITypeSystem;
import org.eclipse.xtext.naming.IQualifiedNameProvider;
import org.eclipse.xtext.resource.IEObjectDescription;
import org.eclipse.xtext.resource.IResourceDescription;
import org.eclipse.xtext.resource.IResourceServiceProvider;
import org.eclipse.xtext.resource.impl.EObjectDescriptionLookUp;
import org.eclipse.xtext.scoping.IScope;
import org.eclipse.xtext.scoping.impl.DefaultGlobalScopeProvider;
import org.eclipse.xtext.scoping.impl.FilteringScope;
import org.eclipse.xtext.scoping.impl.SelectableBasedScope;
import org.eclipse.xtext.scoping.impl.SimpleScope;

import com.google.common.base.Predicate;
import com.google.common.collect.Iterables;
import com.google.inject.Inject;

public class TypesGlobalScopeProvider extends DefaultGlobalScopeProvider {

	@Inject
	private ITypeSystem typeSystem;

	@Inject
	private ILibraryProvider libraryProvider;

	@Inject
	private IQualifiedNameProvider qualifiedNameProvider;
	
	@Inject
	private IResourceServiceProvider.Registry serviceProviderRegistry;

	public IScope getScope(Resource context, EReference reference, Predicate<IEObjectDescription> filter) {
		IScope superScope = super.getScope(context, reference, filter);
		superScope = addLibraryScope(context, reference, superScope);
		superScope = filterExportable(context, reference, superScope);
		return superScope;
	}

	public static IScope filterExportable(Resource context, EReference reference, IScope superScope) {
		String resourcePackage = null;
		if(!context.getContents().isEmpty()) {
			EObject root = context.getContents().get(0);
			EStructuralFeature nameFeature = root.eClass().getEStructuralFeature("name");
			if(nameFeature != null) {
				Object resourcePackageObj = root.eGet(nameFeature);
				if(resourcePackageObj != null) {
					resourcePackage = resourcePackageObj.toString();
				}
			}
		}
		final String resourcePackageName = resourcePackage;
		
		return new FilteringScope(superScope, new Predicate<IEObjectDescription>() {
			
			@Override
			public boolean apply(IEObjectDescription input) {
				boolean inSamePackage = resourcePackageName != null 
						&& input.getQualifiedName().toString().startsWith(resourcePackageName);
				String isExported = input.getUserData(BaseResourceDescriptionStrategy.EXPORTED);
				
				boolean includeInScope = inSamePackage || isExported == null || "true".equals(isExported);
				return includeInScope;
			}
			
		});
	}

	private SimpleScope addLibraryScope(Resource context, EReference reference, IScope superScope) {
		return new SimpleScope(superScope, getLibraryScope(context, reference).getAllElements());
	}

	protected IScope getLibraryScope(Resource context, EReference reference) {
		Iterable<URI> defaultLibraries = Iterables.<URI>concat(libraryProvider.getLibraries());
		List<IEObjectDescription> descriptions = new ArrayList<>();
		for(URI uri : defaultLibraries) {
			// we have previously loaded all libraries into the resource set
			Resource resource = context.getResourceSet().getResource(uri, false);
			if(resource != null) {
				IResourceDescription description = serviceProviderRegistry.getResourceServiceProvider(uri).getResourceDescriptionManager().getResourceDescription(resource);
				Iterables.addAll(descriptions, description.getExportedObjects());				
			}
		}
		return SelectableBasedScope.createScope(IScope.NULLSCOPE, new EObjectDescriptionLookUp(descriptions), reference.getEReferenceType(), isIgnoreCase(reference));
	}

	protected IScope addTypeSystemScope(Resource context, EReference reference, IScope superScope) {
		superScope = new TypeSystemAwareScope(superScope, typeSystem, qualifiedNameProvider,
				reference.getEReferenceType(), reference == TypesPackage.Literals.TYPE__SUPER_TYPES);
		return superScope;
	}
}
