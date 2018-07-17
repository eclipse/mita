package org.eclipse.mita.base.typesystem.infra

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.IConstraintFactory
import org.eclipse.mita.base.typesystem.ISymbolFactory
import org.eclipse.xtext.diagnostics.IDiagnosticConsumer
import org.eclipse.xtext.linking.lazy.LazyLinker

class MitaLinker extends LazyLinker {

	@Inject
	protected IConstraintFactory constraintFactory;
	
	@Inject
	protected ISymbolFactory symbolFactory;
	
	override linkModel(EObject model, IDiagnosticConsumer diagnosticsConsumer) {
		super.linkModel(model, diagnosticsConsumer)
	
		val symbols = symbolFactory.create(model);
		val constraints = constraintFactory.create(symbols, model);
		println(constraints);
	}
	
}
