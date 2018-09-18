package org.eclipse.mita.base.scoping

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.xtext.resource.IResourceDescription
import org.eclipse.xtext.resource.IResourceDescriptions
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.resource.containers.StateBasedContainerManager
import org.eclipse.xtext.resource.impl.AbstractContainer
import com.google.common.collect.Lists

class MitaContainerManager extends StateBasedContainerManager {
	
	public static final String STDLIB_CONTAINER_HANDLE = "Mita_Stdlib";
	public static final String DEPENDENCIES_CONTAINER_HANDLE = "Mita_Dependencies";
	
	@Inject
	protected ILibraryProvider libraryProvider;
	
	@Inject
	protected IResourceDescription.Manager resourceDescriptionManager;
	
	@Inject
	protected Provider<XtextResourceSet> resourceSetProvider;
	
	protected Iterable<IResourceDescription> stdlibDescriptions;
	protected Iterable<IResourceDescription> dependencyDescriptions;
	
	
	protected def getStdlibDescriptions() {
		if(this.stdlibDescriptions === null) {
			val resourceSet = resourceSetProvider.get();
			this.stdlibDescriptions = Lists.newArrayList(libraryProvider
				.standardLibraries
				.map[ resourceSet.getResource(it, true) ]
				.map[ resourceDescriptionManager.getResourceDescription(it) ]
			);
		}		
		return this.stdlibDescriptions;		
	}
	
	protected def getDependencyDescriptions() {
		if(this.dependencyDescriptions === null) {
			val resourceSet = resourceSetProvider.get();
			this.dependencyDescriptions = Lists.newArrayList(libraryProvider
				.libraries
				.map[ resourceSet.getResource(it, true) ]
				.map[ resourceDescriptionManager.getResourceDescription(it) ]
			);
		}		
		return this.dependencyDescriptions;
	}
	
	override protected createContainer(String handle, IResourceDescriptions resourceDescriptions) {
		if(handle == STDLIB_CONTAINER_HANDLE) {
			return new AbstractContainer() {
				
				override getResourceDescriptions() {
					return getStdlibDescriptions();
				}
				
			}
		} else if(handle == DEPENDENCIES_CONTAINER_HANDLE) {
			return new AbstractContainer() {
				
				override getResourceDescriptions() {
					return getDependencyDescriptions();
				}
				
			}
		} else {
			return super.createContainer(handle, resourceDescriptions);			
		}
		
	}
	
}