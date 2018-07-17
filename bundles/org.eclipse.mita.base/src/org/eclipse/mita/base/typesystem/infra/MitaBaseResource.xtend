package org.eclipse.mita.base.typesystem.infra

import org.eclipse.xtext.parser.IParseResult
import org.eclipse.xtext.resource.XtextResource
import com.google.inject.Inject
import org.eclipse.xtext.resource.impl.ListBasedDiagnosticConsumer
import org.eclipse.xtext.diagnostics.Severity

class MitaBaseResource extends XtextResource {
	
	@Inject
	protected MitaTypeLinker typeLinker;
	
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
	
}
