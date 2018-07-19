package org.eclipse.mita.base.typesystem.infra

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.typesystem.IConstraintFactory
import org.eclipse.mita.base.typesystem.ISymbolFactory
import org.eclipse.mita.base.typesystem.solver.ConstraintSolver
import org.eclipse.xtext.diagnostics.IDiagnosticConsumer
import org.eclipse.xtext.linking.impl.Linker

class MitaLinker extends Linker {

	@Inject
	protected IConstraintFactory constraintFactory;
	
	@Inject
	protected ConstraintSolver constraintSolver;
	
	@Inject
	protected ISymbolFactory symbolFactory;
	
	override linkModel(EObject model, IDiagnosticConsumer diagnosticsConsumer) {
		super.linkModel(model, diagnosticsConsumer)
	
		val symbols = symbolFactory.create(model);
		val constraints = constraintFactory.create(symbols, model);
		println(constraints);
		
		val solution = constraintSolver.solve(constraints);
		println(solution);
	}
	
	override protected isClearAllReferencesRequired(Resource resource) {
		false
	}
	
}
