package org.eclipse.mita.base.typesystem;

import org.eclipse.emf.ecore.resource.ResourceSet;

public interface ILibraryProvider {

	public void ensureLibrariesLoaded(ResourceSet rs);
	
}
