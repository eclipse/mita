package org.eclipse.mita.base.typesystem.infra

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.IConstraintFactory
import org.eclipse.mita.base.typesystem.ISymbolFactory
import org.eclipse.xtext.diagnostics.IDiagnosticConsumer
import org.eclipse.xtext.linking.lazy.LazyLinker
import org.eclipse.emf.common.notify.Adapter
import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.mita.base.typesystem.infra.SymbolTableAdapter.SymbolTableAdapterHandler

class MitaLinker extends LazyLinker {

	@Inject
	protected IConstraintFactory constraintFactory;
	
	@Inject
	protected ISymbolFactory symbolFactory;
	
	@Inject
	protected SymbolTableAdapterHandler globalTableHandler;
	
	override linkModel(EObject model, IDiagnosticConsumer diagnosticsConsumer) {
		super.linkModel(model, diagnosticsConsumer)
	
		val symbols = symbolFactory.create(model);
		
		globalTableHandler.addTable(model, symbols);

		val constraints = constraintFactory.create(symbols, model);
		println(constraints);
	}
}
