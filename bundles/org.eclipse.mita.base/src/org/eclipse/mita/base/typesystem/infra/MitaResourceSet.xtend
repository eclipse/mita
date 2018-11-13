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
