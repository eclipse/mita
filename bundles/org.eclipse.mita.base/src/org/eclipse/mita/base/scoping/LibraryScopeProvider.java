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

import java.util.HashSet;
import java.util.Set;

import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.mita.base.expressions.scoping.AbstractLibraryGlobalScopeProvider;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class LibraryScopeProvider extends AbstractLibraryGlobalScopeProvider {

	@Inject
	protected ILibraryProvider libraryProvider;
	
	@Override
	protected Set<URI> getLibraries(Resource context) {
		Set<URI> result = new HashSet<>();
		for(URI uri : libraryProvider.getDefaultLibraries()) {
			result.add(uri);
		}
		for(URI uri : libraryProvider.getImportedLibraries(context)) {
			result.add(uri);
		}
		return result;
	}

}
