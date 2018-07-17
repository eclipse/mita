package org.eclipse.mita.base.typesystem.infra

import org.eclipse.xtext.parser.IParseResult
import org.eclipse.xtext.resource.XtextResource

class MitaBaseResource extends XtextResource {
	
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
	
}
