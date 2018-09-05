package org.eclipse.mita.base.typesystem.infra

import org.eclipse.xtext.parser.IParseResult
import org.eclipse.xtext.resource.XtextResource
import com.google.inject.Inject
import org.eclipse.xtext.resource.impl.ListBasedDiagnosticConsumer
import org.eclipse.xtext.diagnostics.Severity
import java.util.Map
import java.io.IOException
import org.eclipse.emf.ecore.impl.EObjectImpl
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.emf.common.util.URI
import org.eclipse.xtext.util.OnChangeEvictingCache
import com.google.inject.name.Named
import org.eclipse.emf.ecore.impl.BasicEObjectImpl
import org.eclipse.emf.ecore.impl.MinimalEObjectImpl

class MitaBaseResource extends XtextResource {
	
	@Inject @Named("typeLinker")
	protected MitaTypeLinker typeLinker;
	@Inject @Named("typeDependentLinker")
	protected MitaTypeLinker typeDependentLinker;
	
	@Accessors
	protected boolean dependenciesLoaded = false;
		
	override load(Map<?, ?> options) throws IOException {
		super.load(options)
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
		// doLinking();
		// mark everything as not-a-proxy
	}
	
	override public doLinking() {
		super.doLinking()
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
