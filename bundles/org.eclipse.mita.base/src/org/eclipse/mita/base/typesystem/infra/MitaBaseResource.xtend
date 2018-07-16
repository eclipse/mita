package org.eclipse.mita.base.typesystem.infra

import org.eclipse.xtext.resource.XtextResource
import com.google.inject.Inject
import java.util.Map
import java.io.IOException

class MitaBaseResource extends XtextResource {
	
	@Inject
	protected org.eclipse.mita.base.typesystem.ILibraryProvider libraryProvider;
	
	override load(Map<?, ?> options) throws IOException {		
		super.load(options)
		libraryProvider.ensureLibrariesLoaded(this.resourceSet);
	}
	
}
