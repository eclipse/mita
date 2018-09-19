package org.eclipse.mita.base.ui.index

import com.google.inject.Inject
import java.util.Set
import org.eclipse.emf.common.util.URI
import org.eclipse.mita.base.scoping.ILibraryProvider
import org.eclipse.mita.base.scoping.MitaContainerManager
import org.eclipse.xtext.resource.IResourceDescriptions
import org.eclipse.xtext.resource.containers.IAllContainersState
import org.eclipse.xtext.ui.containers.WorkspaceProjectsState
import java.util.HashSet

class MitaWorkspaceProjectsState extends WorkspaceProjectsState {
	
	@Inject
	protected ILibraryProvider libraryProvider;
	
	protected Set<URI> typeUris;
	protected Set<URI> stdlibUris;
	protected Set<URI> dependencyUris;
	
	static class Provider implements IAllContainersState.Provider {
		@Inject
		protected MitaWorkspaceProjectsState state;
		
		override get(IResourceDescriptions context) {
			return state;	
		}
	}
	
	override protected doInitHandle(URI uri) {
		if(getTypeUris().contains(uri)) {
			return MitaContainerManager.TYPES_CONTAINER_HANDLE;
		} else if(getStdlibUris().contains(uri)) {
			return MitaContainerManager.STDLIB_CONTAINER_HANDLE;
		} else if(getDependencyUris().contains(uri)) {
			return MitaContainerManager.DEPENDENCIES_CONTAINER_HANDLE;
		} else {
			return super.doInitHandle(uri);
		}
	}
	
	override protected doInitContainedURIs(String containerHandle) {
		if(containerHandle == MitaContainerManager.TYPES_CONTAINER_HANDLE) {
			return getTypeUris();
		}
		if(containerHandle == MitaContainerManager.STDLIB_CONTAINER_HANDLE) {
			return getStdlibUris();
		} else if(containerHandle == MitaContainerManager.DEPENDENCIES_CONTAINER_HANDLE) {
			return getDependencyUris();
		} else {
			super.doInitContainedURIs(containerHandle);			
		}
	}
	
	override protected doInitVisibleHandles(String handle) {
		val result = newArrayList;
		
		// stdlib depends on stdlib_base_types
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
	
	protected def getTypeUris() {
		// at minimum we need to load stdlib_types
		if(typeUris === null) {
			typeUris = new HashSet();
			typeUris.addAll(getStdlibUris().filter[it.lastSegment == "stdlib_types.mita"]);
		}
		return typeUris;
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