package org.eclipse.mita.base.typesystem.infra

import com.google.common.collect.Iterables
import com.google.gson.Gson
import com.google.inject.Inject
import java.util.HashMap
import java.util.HashSet
import java.util.List
import java.util.Map
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
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.AbstractFileSystemAccess2
import org.eclipse.xtext.generator.OutputConfiguration
import org.eclipse.xtext.generator.URIBasedFileSystemAccess
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.util.IResourceScopeCache
import org.eclipse.xtext.util.OnChangeEvictingCache

import static extension org.eclipse.mita.base.util.BaseUtils.*

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
	
	@Accessors
	protected Map<String, Map<String, List<String>>> projectConfig = new HashMap();
	
	protected boolean isLoadingResources = false;
	protected boolean isLinkingTypes = false;
	protected boolean isLinkingTypeDependent = false;
	
	override getResource(URI uri, boolean loadOnDemand) {
		val result = super.getResource(uri, loadOnDemand);
		if(!loadOnDemand) {
			return result;
		}
		if(result instanceof MitaBaseResource) {
			val thisIsLoadingResources = !isLoadingResources;
			try {
				if(!result.dependenciesLoaded) {
					if(thisIsLoadingResources) {
						isLoadingResources = true;
						val projectFileURI = this.resources.filter(MitaBaseResource).map[it.URI].findFirst[it.scheme == "platform" && it.segment(0) == "resource"]
						val projectConfigJson = uri.trimSegments(1).appendSegment("project.json");
						val fsa = new URIBasedFileSystemAccess();
						fsa.baseDir = projectFileURI.trimSegments(1);
						// this is required, idk
						fsa.converter = uriConverter;
						val outputConfig = new OutputConfiguration("DEFAULT_OUTPUT");
						// project name
						outputConfig.outputDirectory = fsa.baseDir.lastSegment;
						fsa.outputConfigurations.put(AbstractFileSystemAccess2.DEFAULT_OUTPUT, outputConfig);
						val jsonTxtContents = fsa.readTextFile("project.json");
						val gson = new Gson();
						projectConfig = gson.fromJson(jsonTxtContents.toString, Map)
						
						//val projectConfig = super.getResource(projectConfigJson, true);
						
						val loadedLibraries = ensureLibrariesAreLoaded();
						val loadedResources = loadRequiredResources(#[result] + loadedLibraries.filter(MitaBaseResource), new HashSet());
					}
					result.dependenciesLoaded = true;
				}
				if(thisIsLoadingResources) {
						//linkTypes(loadedResources.filter(MitaBaseResource));
					val mitaResources = this.resources.filter(MitaBaseResource).force;
					linkTypes(mitaResources);
					linkOthers(mitaResources);
				}
				if(thisIsLoadingResources && result.errors.empty) {
					//result.doLinking();
					PreventRecursion.preventRecursion(result, [|
						computeTypes();
						//linkWithTypes(result);	
						return null;
					]);					
				}
			}
			finally {
				if(thisIsLoadingResources) {					
					isLoadingResources = false;
				}
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
	
	protected def linkOthers(Iterable<MitaBaseResource> resources) {
		if(isLinkingTypeDependent) {
			return;
		}
		isLinkingTypeDependent = true;
		resources.forEach[ it.doLinkTypeDependent ];
		isLinkingTypeDependent = false;
	}
	
	public def getLatestSolution() {
		return latestSolution;
	}
	
}
