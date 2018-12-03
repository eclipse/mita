package org.eclipse.mita.base.typesystem.infra

import java.util.HashMap
import java.util.List
import java.util.Map
import org.eclipse.emf.common.util.URI
import org.eclipse.mita.base.typesystem.solver.ConstraintSolution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.resource.XtextResourceSet

class MitaResourceSet extends XtextResourceSet {

	@Accessors
	protected ConstraintSolution latestSolution;
	
	@Accessors
	protected Map<String, Map<String, List<String>>> projectConfig = new HashMap();
	
	protected boolean isLoadingResources = false;
	protected boolean isLinkingTypes = false;
	protected boolean isLinkingTypeDependent = false;
	
	override getResource(URI uri, boolean loadOnDemand) {
		return super.getResource(uri, loadOnDemand);
	}

//	protected def linkWithTypes(MitaBaseResource resource) {
//		resource.doLinkReferences;
//	}	
}
