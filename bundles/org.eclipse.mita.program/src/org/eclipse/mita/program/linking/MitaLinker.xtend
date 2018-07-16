package org.eclipse.mita.program.linking

import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.diagnostics.IDiagnosticConsumer
import org.eclipse.xtext.linking.lazy.LazyLinker

class MitaLinker extends LazyLinker {
	
	override linkModel(EObject model, IDiagnosticConsumer diagnosticsConsumer) {
		super.linkModel(model, diagnosticsConsumer)
	}
	
}