package org.eclipse.mita.base.ui.index

import com.google.inject.Inject
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import java.util.Set
import org.eclipse.core.resources.IFile
import org.eclipse.core.runtime.Path
import org.eclipse.emf.common.util.URI
import org.eclipse.mita.base.scoping.ILibraryProvider
import org.eclipse.mita.base.scoping.MitaContainerManager
import org.eclipse.mita.base.types.ImportStatement
import org.eclipse.mita.base.types.PackageAssociation
import org.eclipse.xtext.resource.IResourceDescriptions
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.resource.containers.IAllContainersState
import org.eclipse.xtext.ui.containers.WorkspaceProjectsState

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull

class MitaWorkspaceProjectsState extends WorkspaceProjectsState {
	
	@Inject
	protected ILibraryProvider libraryProvider;
	@Inject
	protected com.google.inject.Provider<XtextResourceSet> resourceSetProvider;
	
	protected Set<URI> typeUris;
	protected Set<URI> stdlibUris;
	protected Set<URI> dependencyUris;
	protected Map<String, Set<String>> handleToImportedPackages = new HashMap;
	protected Map<String, Set<URI>> handleToContainedURIs = new HashMap;
	
	static class Provider implements IAllContainersState.Provider {
		@Inject
		protected MitaWorkspaceProjectsState state;
		
		override get(IResourceDescriptions context) {
			return state;	
		}
	}
	
	protected XtextResourceSet resourceSet;
		
	protected def getResourceSet() {
		resourceSet ?: (resourceSetProvider.get() => [this.resourceSet = it]);
	}
	
	protected def <T> void putOrAdd(Map<String, Set<T>> m, String handle, Iterable<T> imports) {
		if(!m.containsKey(handle)) {
			m.put(handle, new HashSet<T>());
		}
		val set = m.get(handle);
		set.addAll(imports);
	}
	
	override protected doInitHandle(URI uri) {
		if(getTypeUris().contains(uri)) {
			return MitaContainerManager.TYPES_CONTAINER_HANDLE;
		} else if(getStdlibUris().contains(uri)) {
			return MitaContainerManager.STDLIB_CONTAINER_HANDLE;
		} else if(getDependencyUris().contains(uri)) {
			return MitaContainerManager.DEPENDENCIES_CONTAINER_HANDLE;
		} else if(uri.fileExtension == "mita") {
			val resource = getResourceSet.getResource(uri, true);
			val program = resource.contents.head.castOrNull(PackageAssociation);
			val pkgName = program.name;
			val imports = #[pkgName] + program.eContents.filter(ImportStatement).map[it.importedNamespace];
			putOrAdd(handleToImportedPackages, pkgName, imports);
			
			val project = getStorages(uri).head?.second;
			if(project !== null) {
				imports.forEach[imprt | 
					val path = new Path(imprt.replaceAll("\\.", "/"));
					val folder = project.getFolder(path);
					if(folder !== null && folder.exists) {
						val mitaFiles = folder
							.members
							.filter(IFile)
							.filter[it.fileExtension == "mita"]
							.map[it.uri]
							.filter[it !== uri]
							.filterNull;
						handleToContainedURIs.put(imprt, new HashSet(mitaFiles.toList));
					}
				]
			}
			return pkgName;
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
		} else if(handleToContainedURIs.containsKey(containerHandle)) {
			return handleToContainedURIs.get(containerHandle);
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
					
					if(handleToImportedPackages.containsKey(handle)) {
						result += handleToImportedPackages.get(handle);
					}
				}
			}
		}
		return result;
	}
	
	protected def getTypeUris() {
		// at minimum we need to load stdlib_types
		if(typeUris === null) {
			typeUris = new HashSet();
			typeUris.addAll(libraryProvider.standardLibraries.filter[it.lastSegment == "stdlib_types.mita"]);
		}
		return typeUris;
	}
	
	protected def getStdlibUris() {
		if(stdlibUris === null) {
			stdlibUris = new HashSet();
			stdlibUris.addAll(libraryProvider.standardLibraries.filter[it.lastSegment != "stdlib_types.mita"]);
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