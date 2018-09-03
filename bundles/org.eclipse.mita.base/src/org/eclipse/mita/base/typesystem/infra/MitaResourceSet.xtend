package org.eclipse.mita.base.typesystem.infra

import com.google.common.collect.Iterables
import com.google.inject.Inject
import java.util.HashSet
import java.util.List
import java.util.Set
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.scoping.ILibraryProvider
import org.eclipse.mita.base.types.ImportStatement
import org.eclipse.mita.base.typesystem.IConstraintFactory
import org.eclipse.mita.base.typesystem.ISymbolFactory
import org.eclipse.mita.base.typesystem.solver.ConstraintSolution
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.IConstraintSolver
import org.eclipse.mita.base.util.PreventRecursion
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.util.OnChangeEvictingCache

import static extension org.eclipse.mita.base.util.BaseUtils.*
import java.io.IOException
import org.eclipse.xtext.util.IResourceScopeCache

class MitaResourceSet extends XtextResourceSet {
	
	@Inject
	protected ILibraryProvider libraryProvider;
	
	@Inject
	protected IPackageResourceMapper packageResourceMapper;
	
	@Inject
	protected OnChangeEvictingCache cache;
	
	@Inject
	protected IConstraintFactory constraintFactory;
	
	@Inject
	protected IConstraintSolver constraintSolver;
	
	@Inject
	protected ISymbolFactory symbolFactory;
	
	protected ConstraintSolution latestSolution;
	
	protected boolean isLoadingResources = false;
	protected boolean isLinkingTypes = false;
	
	override getResource(URI uri, boolean loadOnDemand) {
		val alreadyLoadedResource = this.resources.findFirst[it.URI == uri]
		val result = super.getResource(uri, loadOnDemand);
		if(!loadOnDemand) {
			return result;
		}
		if(result instanceof MitaBaseResource) {
			val thisIsLoadingResources = !isLoadingResources;
			if(!result.dependenciesLoaded) {
				if(thisIsLoadingResources) {
					isLoadingResources = true;
					val loadedLibraries = ensureLibrariesAreLoaded();
					val loadedResources = loadRequiredResources(#[result] + loadedLibraries.filter(MitaBaseResource), new HashSet());
				}
				result.dependenciesLoaded = true;
			}
			if(thisIsLoadingResources) {
					//linkTypes(loadedResources.filter(MitaBaseResource));
				linkTypes(this.resources.filter(MitaBaseResource).force);
			}
			if(thisIsLoadingResources) {
				//result.doLinking();
				
				PreventRecursion.preventRecursion(result, [|
					computeTypes();
					//linkWithTypes(result);	
					return null;
				]);
				isLoadingResources = false;
			}
			
		}
		return result;
	}
		
	override getEObject(URI uri, boolean loadOnDemand) {
		super.getEObject(uri, loadOnDemand)
	}
		
	def linkWithTypes(MitaBaseResource resource) {
		resource.doLinkReferences;
	}
	
	protected def getConstraints(Resource res, IResourceScopeCache cache) {
		cache.get(ConstraintSystem, res, [
			//val symbols = symbolFactory.create(model);
			val result = constraintFactory.create(res.contents.head);
			return result;		
		]);
	}
	
	var isComputingTypes = false;
	protected def computeTypes() {
		if(isComputingTypes) {
			return;
		}
		isComputingTypes = true;
		val constraints = resources.filter(MitaBaseResource).map[ 
			getConstraints(it, it.cache);
		].force;
		
		val allConstraints = ConstraintSystem.combine(constraints);
		latestSolution = constraintSolver.solve(allConstraints);
		isComputingTypes = false;
	}
	
	protected def List<Resource> ensureLibrariesAreLoaded() {
		return libraryProvider.libraries
			.filter[ it.lastSegment.startsWith("stdlib_") ]
			.filter[ uri | !this.resources.exists[ it.URI == uri ] ]
			.map[uri | getResource(uri, true)]
			.force
	}
	
	protected def List<Resource> loadRequiredResources(Iterable<MitaBaseResource> resources, Set<URI> loadedDependencies) {
		// TODO: not sure we need this here ... we're loading all libraries into the resource set anyways, what do a few more files in the project matter?
		resources.flatMap[resource | 
			val root = resource.contents.flatMap[ it.eAllContents.toIterable().filter(ImportStatement) ].toList();
			val requiredResourceURIs = root
				.flatMap[ packageResourceMapper.getResourceURIs(this, QualifiedName.create(it.importedNamespace?.split("\\."))) ];
			val notLoadedResourceURIs = requiredResourceURIs
				.filter[uri | this.resources.findFirst[it.URI == uri] === null];
			loadedDependencies.addAll(notLoadedResourceURIs);
			val requiredResources = notLoadedResourceURIs
				.map[dep |
					loadedDependencies.add(dep);
					getResource(dep, true);
				].force
			Iterables.concat(requiredResources.filter[!(it instanceof MitaBaseResource)], loadRequiredResources(requiredResources.filter(MitaBaseResource), loadedDependencies));			
		].force
	}
	
	protected def linkTypes(Iterable<MitaBaseResource> resources) {
		if(isLinkingTypes) {
			return;
		}
		isLinkingTypes = true;
		resources.forEach[ it.doLinkTypes ];
		isLinkingTypes = false;
	}
	
	public def getLatestSolution() {
		return latestSolution;
	}
	
}
