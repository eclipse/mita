package org.eclipse.mita.base.typesystem.infra

import com.google.inject.Inject
import com.google.inject.name.Named
import java.io.IOException
import java.util.List
import java.util.Map
import org.eclipse.emf.ecore.impl.EObjectImpl
import org.eclipse.emf.ecore.impl.MinimalEObjectImpl
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.scoping.ILibraryProvider
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.diagnostics.Severity
import org.eclipse.xtext.parser.IParseResult
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.resource.impl.ListBasedDiagnosticConsumer

import static extension org.eclipse.mita.base.util.BaseUtils.force;
import org.eclipse.xtext.linking.lazy.LazyLinkingResource

//class MitaBaseResource extends XtextResource {
class MitaBaseResource extends LazyLinkingResource {
	
	@Inject @Named("typeLinker")
	protected MitaTypeLinker typeLinker;
	@Inject @Named("typeDependentLinker")
	protected MitaTypeLinker typeDependentLinker;
	
	@Inject
	protected ILibraryProvider libraryProvider;
	
	@Accessors
	protected boolean dependenciesLoaded = false;
		
	override load(Map<?, ?> options) throws IOException {
		super.load(options)
		ensureLibrariesAreLoaded();
	}
	
	override updateInternalState(IParseResult newParseResult) {
		this.parseResult = newParseResult;
		val newRootASTElement = parseResult.getRootASTElement();
		val containsRootElement = getContents().contains(newRootASTElement);
		if (newRootASTElement !== null && !containsRootElement) {
			getContents().add(0, newRootASTElement);			
		}
		reattachModificationTracker(newRootASTElement);
		
		clearErrorsAndWarnings();
		addSyntaxErrors();
		
		// We trigger linking in the resource set once all required resources are loaded
		doLinking();
		// mark everything as not-a-proxy
	}
	
	override public doLinking() {
		super.doLinking()
	}
	
	protected def List<Resource> ensureLibrariesAreLoaded() {
		return libraryProvider.libraries
			.filter[ it.lastSegment.startsWith("stdlib_") ]
			.filter[ uri | !this.resourceSet.resources.exists[ it.URI == uri ] ]
			.map[uri | resourceSet.getResource(uri, true)]
			.force
	}
	
	def doLinkTypes() {
		if (parseResult === null || parseResult.getRootASTElement() === null)
			return;

		val consumer = new ListBasedDiagnosticConsumer();
		typeLinker.linkModel(parseResult.getRootASTElement(), consumer);
		if (!validationDisabled) {
			getErrors().addAll(consumer.getResult(Severity.ERROR));
			getWarnings().addAll(consumer.getResult(Severity.WARNING));
		}
		
	}
	def doLinkTypeDependent() {
		if (parseResult === null || parseResult.getRootASTElement() === null)
			return;

		val consumer = new ListBasedDiagnosticConsumer();
		typeDependentLinker.linkModel(parseResult.getRootASTElement(), consumer);
		if (!validationDisabled) {
			getErrors().addAll(consumer.getResult(Severity.ERROR));
			getWarnings().addAll(consumer.getResult(Severity.WARNING));
		}
		this.contents.map[it.eAllContents].forEach[ l | l.forEach[
			if(it.eIsProxy) {
				if(it instanceof EObjectImpl) {
					it.eSetProxyURI(null);
				}
				if(it instanceof MinimalEObjectImpl) {
					it.eSetProxyURI(null);
				}
			}	
		]]
	}
	
	def doLinkReferences() {
		if (parseResult === null || parseResult.getRootASTElement() === null)
			return;
		val consumer = new ListBasedDiagnosticConsumer();
		linker.linkModel(parseResult.getRootASTElement(), consumer);
		if (!validationDisabled) {
			getErrors().addAll(consumer.getResult(Severity.ERROR));
			getWarnings().addAll(consumer.getResult(Severity.WARNING));
		}
	}
	
}
