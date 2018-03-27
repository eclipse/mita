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

package org.eclipse.mita.types.scoping;

import java.util.Set;

import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.yakindu.base.expressions.scoping.AbstractLibraryGlobalScopeProvider;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class LibraryScopeProvider extends AbstractLibraryGlobalScopeProvider {

	@Inject
	protected TypesLibraryProvider libraryProvider;
	
	@Override
	protected Set<URI> getLibraries(Resource context) {
		return libraryProvider.getLibraries(context);
	}

}
