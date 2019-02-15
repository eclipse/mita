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
		@Inject
		protected ILibraryProvider libraryProvider;
		
		override protected handleAdapterNotFound(ResourceSet resourceSet) {
		 	new MitaResourceSetBasedAllContainersState(libraryProvider, resourceSet);
		}
 	}
	
	@Inject
	protected ILibraryProvider libraryProvider;
	
	protected Set<URI> typeUris;
	protected Set<URI> stdlibUris;
	protected Set<URI> dependencyUris;
	
	new(ILibraryProvider libraryProvider, ResourceSet rs) {
		super(rs)
		this.libraryProvider = libraryProvider;
	}
	
	override getVisibleContainerHandles(String handle) {
		val result = newArrayList;
		
		// stdlib depends on <nothing>
		// dependencies depend on stdlib
		// everything else depends on stdlib and dependencies
		if(handle != MitaContainerManager.TYPES_CONTAINER_HANDLE) {
			result += MitaContainerManager.TYPES_CONTAINER_HANDLE;
						
			if(handle != MitaContainerManager.STDLIB_CONTAINER_HANDLE) {
				result += MitaContainerManager.STDLIB_CONTAINER_HANDLE;
							
				if(handle != MitaContainerManager.DEPENDENCIES_CONTAINER_HANDLE) {
					result += MitaContainerManager.DEPENDENCIES_CONTAINER_HANDLE;			
				}
			}
		}
		
		return result;
	}
	
	override getContainedURIs(String containerHandle) {
		if(containerHandle == MitaContainerManager.TYPES_CONTAINER_HANDLE) {
			return getTypeUris();
		}
		if(containerHandle == MitaContainerManager.STDLIB_CONTAINER_HANDLE) {
			return getStdlibUris();
		} else if(containerHandle == MitaContainerManager.DEPENDENCIES_CONTAINER_HANDLE) {
			return getDependencyUris();
		} else {
			return super.getContainedURIs(containerHandle);
		}
	}
	
	override getContainerHandle(URI uri) {
		if(getTypeUris().contains(uri)) {
			return MitaContainerManager.TYPES_CONTAINER_HANDLE;
		} else if(getStdlibUris().contains(uri)) {
			return MitaContainerManager.STDLIB_CONTAINER_HANDLE;
		} else if(getDependencyUris().contains(uri)) {
			return MitaContainerManager.DEPENDENCIES_CONTAINER_HANDLE;
		} else {
			return super.getContainerHandle(uri);
		}
	}
	
	override isEmpty(String containerHandle) {
		return containerHandle != MitaContainerManager.TYPES_CONTAINER_HANDLE 
			&& containerHandle != MitaContainerManager.STDLIB_CONTAINER_HANDLE 
			&& containerHandle != MitaContainerManager.DEPENDENCIES_CONTAINER_HANDLE 
			&& super.isEmpty(containerHandle);
	}
		
	protected def getTypeUris() {
		if(typeUris === null) {
			typeUris = new HashSet();
			typeUris.addAll(libraryProvider.standardLibraries.filter[it.lastSegment != "stdlib_types.mita"]);
		}
		return typeUris;
	}
	
	protected def getStdlibUris() {
		if(stdlibUris === null) {
			stdlibUris = new HashSet();
			stdlibUris.addAll(libraryProvider.standardLibraries.reject[it.lastSegment != "stdlib_types.mita"]);
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