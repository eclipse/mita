package org.eclipse.mita.base.typesystem.infra

import com.google.inject.Inject
import java.util.HashSet
import java.util.Set
import org.eclipse.emf.common.util.URI
import org.eclipse.mita.base.scoping.ILibraryProvider
import org.eclipse.mita.base.types.ImportStatement
import org.eclipse.mita.base.typesystem.IConstraintFactory
import org.eclipse.mita.base.typesystem.ISymbolFactory
import org.eclipse.mita.base.typesystem.solver.ConstraintSolver
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.util.OnChangeEvictingCache

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
	protected ConstraintSolver constraintSolver;
	
	@Inject
	protected ISymbolFactory symbolFactory;
	
	override getResource(URI uri, boolean loadOnDemand) {
		val result = super.getResource(uri, loadOnDemand);
		if(result instanceof MitaBaseResource) {
			if(loadOnDemand) {
				ensureLibrariesAreLoaded();
				loadRequiredResources(result, new HashSet());
				
				linkTypes();
				result.doLinking();
				
				computeTypes();
			}
		}
		return result;
	}
	
	protected def computeTypes() {
		val constraints = resources.map[ 
			val model = it.contents.head;
			cache.get(ConstraintSystem, it, [
				val symbols = symbolFactory.create(model);
				val result = constraintFactory.create(symbols, model);
				return result;		
			]);
		];
		
		val allConstraints = ConstraintSystem.combine(constraints);
		val solution = constraintSolver.solve(allConstraints);
		println('''
		«allConstraints»
		Issues:
			«FOR issue : constraintSolver.issues SEPARATOR "\n"»«issue»«ENDFOR»
		Solution:
			«solution»
		''')
	}
	
	protected def void ensureLibrariesAreLoaded() {
		for(uri : libraryProvider.libraries.filter[ it.lastSegment.startsWith("stdlib_") ]) {
			if(this.resources.findFirst[ it.URI == uri ] === null) {
				getResource(uri, true);				
			}
		}
	}
	
	protected def void loadRequiredResources(MitaBaseResource resource, Set<URI> loadedDependencies) {
		// TODO: not sure we need this here ... we're loading all libraries into the resource set anyways, what do a few more files in the project matter?
		val root = resource.contents.flatMap[ it.eAllContents.toIterable().filter(ImportStatement) ].toList();
		val requiredResources = root.flatMap[ packageResourceMapper.getResourceURIs(this, QualifiedName.create(it.importedNamespace?.split("\\."))) ];
		
		for(dep : requiredResources) {
			if(!loadedDependencies.contains(dep)) {
				loadedDependencies.add(dep);
				val r = super.getResource(dep, true);
				if(r instanceof MitaBaseResource) {
					loadRequiredResources(r, loadedDependencies);
				}
			}
		}			
	}
	
	protected def linkTypes() {
		resources.filter(MitaBaseResource).forEach[ it.doLinkTypes ];
	}
	
}
