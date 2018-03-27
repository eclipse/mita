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

import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.eclipse.emf.common.util.TreeIterator;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.resource.Resource;

import org.eclipse.mita.library.extension.LibraryExtensions;
import org.eclipse.mita.library.extension.LibraryExtensions.LibraryDescriptor;
import org.eclipse.mita.types.ImportStatement;
import com.google.common.collect.Iterables;
import com.google.common.collect.Lists;
import com.google.common.collect.Sets;

public class TypesLibraryProvider {

	public Set<URI> getLibraries(Resource context) {
		Set<URI> result = new HashSet<>();
		if (context.getURI().isPlatformPlugin()) {
			LibraryDescriptor descriptors = LibraryExtensions.getContainingLibrary(context.getURI());
			List<String> dependencies = descriptors.getDependencies();
			for (String string : dependencies) {
				LibraryDescriptor dependency = LibraryExtensions.getDescriptor(string,
						Iterables.getLast(LibraryExtensions.getAvailableVersions(string)));
				result.addAll(dependency.getResourceUris());
			}
			return result;
		}

		List<LibraryDescriptor> importedLibraries = getImportedLibraries(context);
		Set<URI> libraries = Sets.newHashSet();
		for (LibraryDescriptor libraryDescriptor : importedLibraries) {
			libraries.addAll(libraryDescriptor.getResourceUris());
		}
		return libraries;
	}

	public List<LibraryDescriptor> getImportedLibraries(Resource context) {
		List<LibraryDescriptor> defaultLibraries = LibraryExtensions.getDefaultLibraries();
		TreeIterator<EObject> allContents = context.getAllContents();
		while (allContents.hasNext()) {
			EObject next = allContents.next();
			if (next instanceof ImportStatement) {
				String importedNamespace = ((ImportStatement) next).getImportedNamespace();
				defaultLibraries.addAll(Lists.newArrayList(LibraryExtensions.getDescriptors(importedNamespace)));
			}
		}
		return defaultLibraries;
	}
}
