package org.eclipse.mita.base.scoping

import com.google.common.collect.Lists
import com.google.inject.Inject
import com.google.inject.Provider
import com.google.inject.Singleton
import java.util.HashMap
import java.util.Map
import org.eclipse.xtext.resource.IResourceDescription
import org.eclipse.xtext.resource.IResourceDescriptions
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.resource.containers.StateBasedContainerManager
import org.eclipse.xtext.resource.impl.AbstractContainer
import org.eclipse.emf.common.util.URI

@Singleton
class MitaContainerManager extends StateBasedContainerManager {
	
	public static final String TYPES_CONTAINER_HANDLE = "Mita_Types";
	public static final String STDLIB_CONTAINER_HANDLE = "Mita_Stdlib";
	public static final String DEPENDENCIES_CONTAINER_HANDLE = "Mita_Dependencies";
	
	@Inject
	protected ILibraryProvider libraryProvider;
	
	@Inject
	protected IResourceDescription.Manager resourceDescriptionManager;
	
	@Inject
	protected Provider<XtextResourceSet> resourceSetProvider;
	
	protected Iterable<IResourceDescription> typesDescriptions;
	protected Iterable<IResourceDescription> stdlibDescriptions;
	protected Iterable<IResourceDescription> dependencyDescriptions;
	protected Map<String, Iterable<IResourceDescription>> packageDescriptions = new HashMap;
	
	protected XtextResourceSet resourceSet;
	
	new() {
		print("");
	}
	
	protected def getResourceSet() {
		resourceSet ?: (resourceSetProvider.get() => [this.resourceSet = it]);
	}
	
	protected def getTypeDescriptions() {
		if(this.typesDescriptions === null) {
			val resourceSet = getResourceSet;
			this.typesDescriptions = Lists.newArrayList(libraryProvider
				.standardLibraries
				.filter[it.lastSegment == "stdlib_types.mita"]
				.map[ resourceSet.getResource(it, true) ]
				.map[ resourceDescriptionManager.getResourceDescription(it) ]
			);
		}		
		return this.typesDescriptions;		
	}
	
	protected def getStdlibDescriptions() {
		if(this.stdlibDescriptions === null) {
			val resourceSet = getResourceSet;
			this.stdlibDescriptions = Lists.newArrayList(libraryProvider
				.standardLibraries
				.filter[it.lastSegment != "stdlib_types.mita"]
				.map[ resourceSet.getResource(it, true) ]
				.map[ resourceDescriptionManager.getResourceDescription(it) ]
			);
		}		
		return this.stdlibDescriptions;		
	}
	
	protected def getDependencyDescriptions() {
		if(this.dependencyDescriptions === null) {
			val resourceSet = getResourceSet;
			this.dependencyDescriptions = Lists.newArrayList(libraryProvider
				.libraries
				.map[ resourceSet.getResource(it, true) ]
				.map[ resourceDescriptionManager.getResourceDescription(it) ]
			);
		}		
		return this.dependencyDescriptions;
	}
	
	protected def getPackageDescriptions(Iterable<URI> uris, String handle) {
		if(!this.packageDescriptions.containsKey(handle)) {
			val resourceSet = getResourceSet;
			this.packageDescriptions.put(handle, uris
				.map[resourceSet.getResource(it, true)]
				.map[resourceDescriptionManager.getResourceDescription(it)]
			);
		}
		return this.packageDescriptions.get(handle);
	}
	
	override protected createContainer(String handle, IResourceDescriptions resourceDescriptions) {
		if(handle == TYPES_CONTAINER_HANDLE) {
			return new AbstractContainer() {
				override toString() {
					return "MitaTypesContainer";
				}
				override getResourceDescriptions() {
					return getTypeDescriptions();
				}
				
			}
		} else if(handle == STDLIB_CONTAINER_HANDLE) {
			return new AbstractContainer() {
				override toString() {
					return "MitaStdlibsContainer";
				}
				override getResourceDescriptions() {
					return getStdlibDescriptions();
				}
				
			}
		} else if(handle == DEPENDENCIES_CONTAINER_HANDLE) {
			return new AbstractContainer() {
				override toString() {
					return "MitaDependenciesContainer";
				}
				override getResourceDescriptions() {
					return getDependencyDescriptions();
				}
				
			}
		} else {
			val uris = resourceDescriptions.state.getContainedURIs(handle);
			return new AbstractContainer() {
				override toString() {
					return handle + "Container";
				}
				override getResourceDescriptions() {
					return getPackageDescriptions(uris, handle);
				}				
			}	
		}
		
	}
	
}