package org.eclipse.mita.base.typesystem.infra

import com.google.inject.Inject
import java.util.HashSet
import java.util.Set
import org.eclipse.emf.common.util.URI
import org.eclipse.mita.base.types.ImportStatement
import org.eclipse.mita.base.typesystem.ILibraryProvider
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.XtextResourceSet

class MitaResourceSet extends XtextResourceSet {
	
	@Inject
	protected ILibraryProvider libraryProvider;
	
	@Inject
	protected IPackageResourceMapper packageResourceMapper;
	
	override getResource(URI uri, boolean loadOnDemand) {
		val result = super.getResource(uri, loadOnDemand);
		if(result instanceof MitaBaseResource) {
			if(loadOnDemand) {
				libraryProvider.ensureLibrariesLoaded(this);
				loadRequiredResources(result, new HashSet());
				
				linkTypes();
				result.doLinking();
			}
		}
		return result;
	}
	
	protected def void loadRequiredResources(MitaBaseResource resource, Set<URI> loadedDependencies) {
		val root = resource.contents.flatMap[ it.eAllContents.toIterable().filter(ImportStatement) ].toList();
		val requiredResources = root.flatMap[ packageResourceMapper.getResources(this, QualifiedName.create(it.importedNamespace?.split("\\."))) ];
		
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
