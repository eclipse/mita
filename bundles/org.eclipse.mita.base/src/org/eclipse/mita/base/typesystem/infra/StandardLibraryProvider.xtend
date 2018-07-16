package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.mita.library.^extension.LibraryExtensions
import org.eclipse.mita.library.^extension.LibraryExtensions.LibraryDescriptor

class StandardLibraryProvider implements org.eclipse.mita.base.typesystem.ILibraryProvider {
	
	override ensureLibrariesLoaded(ResourceSet resourceSet) {
		for(LibraryDescriptor desc : LibraryExtensions.getDefaultLibraries()) {
			for(uri: desc.resourceUris) {
				resourceSet.getResource(uri, true);
			}
		}
	}
	
}
