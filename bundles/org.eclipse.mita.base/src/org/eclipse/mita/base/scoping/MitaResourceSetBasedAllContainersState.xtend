package org.eclipse.mita.base.scoping

import com.google.inject.Inject
import java.util.HashSet
import java.util.Set
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtext.resource.containers.FlatResourceSetBasedAllContainersState
import org.eclipse.xtext.resource.containers.ResourceSetBasedAllContainersStateProvider

class MitaResourceSetBasedAllContainersState extends FlatResourceSetBasedAllContainersState {
	
	static class Provider extends ResourceSetBasedAllContainersStateProvider {
		override protected handleAdapterNotFound(ResourceSet resourceSet) {
		 	new MitaResourceSetBasedAllContainersState(resourceSet);
		}
 	}
	
	@Inject
	protected ILibraryProvider libraryProvider;
	
	protected Set<URI> stdlibUris;
	protected Set<URI> dependencyUris;
	
	new(ResourceSet rs) {
		super(rs)
	}
	
	override getVisibleContainerHandles(String handle) {
		val result = newArrayList;
		
		// stdlib depends on <nothing>
		// dependencies depend on stdlib
		// everything else depends on stdlib and dependencies
		if(handle != MitaContainerManager.STDLIB_CONTAINER_HANDLE) {
			result += MitaContainerManager.STDLIB_CONTAINER_HANDLE;
						
			if(handle != MitaContainerManager.DEPENDENCIES_CONTAINER_HANDLE) {
				result += MitaContainerManager.DEPENDENCIES_CONTAINER_HANDLE;			
			}
		}
		
		return result;
	}
	
	override getContainedURIs(String containerHandle) {
		if(containerHandle == MitaContainerManager.STDLIB_CONTAINER_HANDLE) {
			return getStdlibUris();
		} else if(containerHandle == MitaContainerManager.DEPENDENCIES_CONTAINER_HANDLE) {
			return getDependencyUris();
		} else {
			return super.getContainedURIs(containerHandle);
		}
	}
	
	override getContainerHandle(URI uri) {
		if(getStdlibUris().contains(uri)) {
			return MitaContainerManager.STDLIB_CONTAINER_HANDLE;
		} else if(getDependencyUris().contains(uri)) {
			return MitaContainerManager.DEPENDENCIES_CONTAINER_HANDLE;
		} else {
			return super.getContainerHandle(uri);
		}
	}
	
	override isEmpty(String containerHandle) {
		return containerHandle == MitaContainerManager.STDLIB_CONTAINER_HANDLE 
			|| containerHandle == MitaContainerManager.DEPENDENCIES_CONTAINER_HANDLE 
			|| super.isEmpty(containerHandle);
	}
	
	protected def getStdlibUris() {
		if(stdlibUris === null) {
			stdlibUris = new HashSet();
			stdlibUris.addAll(libraryProvider.standardLibraries);
		}
		return stdlibUris;
	}
	
	protected def getDependencyUris() {
		if(dependencyUris === null) {
			dependencyUris = new HashSet();
			dependencyUris.addAll(libraryProvider.libraries);
		}
		return dependencyUris;
	}
	
}