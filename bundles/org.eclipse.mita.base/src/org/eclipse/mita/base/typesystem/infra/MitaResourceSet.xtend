package org.eclipse.mita.base.typesystem.infra

import com.google.inject.Inject
import org.eclipse.emf.common.util.URI
import org.eclipse.mita.base.typesystem.ILibraryProvider
import org.eclipse.xtext.resource.XtextResourceSet

class MitaResourceSet extends XtextResourceSet {
	
	@Inject
	protected ILibraryProvider libraryProvider;
	
	
	
	override getResource(URI uri, boolean loadOnDemand) {
		val result = super.getResource(uri, loadOnDemand);
		if(result instanceof MitaBaseResource) {
			if(loadOnDemand) {
				loadRequiredResources(result);
				result.doLinking();
			}
		}
		return result;
	}
	
	protected def loadRequiredResources(MitaBaseResource resource) {
		libraryProvider.ensureLibrariesLoaded(this);
	}
	
}