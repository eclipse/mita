package org.eclipse.mita.base.typesystem.infra

import com.google.inject.Inject
import java.io.IOException
import java.util.Map
import org.eclipse.mita.base.typesystem.ILibraryProvider
import org.eclipse.xtext.resource.XtextResource

class MitaBaseResource extends XtextResource {
	
	@Inject
	protected ILibraryProvider libraryProvider;
	
	override load(Map<?, ?> options) throws IOException {		
		super.load(options)
		libraryProvider.ensureLibrariesLoaded(this.resourceSet);
	}
	
}
