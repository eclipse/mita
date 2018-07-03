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

package org.eclipse.mita.base.scoping;

import java.util.LinkedList;
import java.util.List;

import org.eclipse.emf.common.util.TreeIterator;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.mita.base.types.ImportStatement;
import org.eclipse.mita.library.extension.LibraryExtensions;
import org.eclipse.mita.library.extension.LibraryExtensions.LibraryDescriptor;

/**
 * 
 * @author Christian Weichel - initial contribution and API
 *
 */
public class LibraryProviderImpl implements ILibraryProvider {

	@Override
	public Iterable<URI> getDefaultLibraries() {
		List<URI> result = new LinkedList<>();
		for(LibraryDescriptor desc : LibraryExtensions.getDefaultLibraries()) {
			result.addAll(desc.getResourceUris());
		}
		return result;
	}

	@Override
	public Iterable<URI> getImportedLibraries(Resource context) {
		List<URI> result = new LinkedList<>();
		TreeIterator<EObject> allContents = context.getAllContents();
		while (allContents.hasNext()) {
			EObject next = allContents.next();
			if (next instanceof ImportStatement) {
				String importedNamespace = ((ImportStatement) next).getImportedNamespace();
				
				Iterable<LibraryDescriptor> importsDescriptors = LibraryExtensions.getDescriptors(importedNamespace);
				for(LibraryDescriptor desc : importsDescriptors) {
					result.addAll(desc.getResourceUris());
				}
			}
		}
		return result;
	}
	
}
