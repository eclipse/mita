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

import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EReference;
import org.eclipse.emf.ecore.EStructuralFeature;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.xtext.naming.IQualifiedNameProvider;
import org.eclipse.xtext.resource.IEObjectDescription;
import org.eclipse.xtext.scoping.IScope;
import org.eclipse.xtext.scoping.impl.DefaultGlobalScopeProvider;
import org.eclipse.xtext.scoping.impl.FilteringScope;
import org.eclipse.xtext.scoping.impl.SimpleScope;
import org.eclipse.mita.base.types.TypesPackage;
import org.eclipse.mita.base.types.typesystem.ITypeSystem;

import com.google.common.base.Predicate;
import com.google.inject.Inject;

public class TypesGlobalScopeProvider extends DefaultGlobalScopeProvider {

	@Inject
	private ITypeSystem typeSystem;

	@Inject
	private LibraryScopeProvider libraryScopeProvider;

	@Inject
	private IQualifiedNameProvider qualifiedNameProvider;

	public IScope getScope(Resource context, EReference reference, Predicate<IEObjectDescription> filter) {
		IScope superScope = super.getScope(context, reference, filter);
		superScope = addLibraryScope(context, reference, superScope);
		superScope = addTypeSystemScope(context, reference, superScope);
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
				String isExported = input.getUserData(TypeDSLResourceDescriptionStrategy.EXPORTED);
				
				boolean includeInScope = inSamePackage || isExported == null || "true".equals(isExported);
				return includeInScope;
			}
			
		});
	}

	private SimpleScope addLibraryScope(Resource context, EReference reference, IScope superScope) {
		return new SimpleScope(superScope, getLibraryScope(context, reference).getAllElements());
	}

	protected IScope getLibraryScope(Resource context, EReference reference) {
		return libraryScopeProvider.getScope(context, reference);
	}

	protected IScope addTypeSystemScope(Resource context, EReference reference, IScope superScope) {
		superScope = new TypeSystemAwareScope(superScope, typeSystem, qualifiedNameProvider,
				reference.getEReferenceType(), reference == TypesPackage.Literals.TYPE__SUPER_TYPES);
		return superScope;
	}
}
