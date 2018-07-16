package org.eclipse.mita.base.typesystem.infra

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.IConstraintFactory
import org.eclipse.xtext.diagnostics.IDiagnosticConsumer
import org.eclipse.xtext.linking.lazy.LazyLinker

class MitaLinker extends LazyLinker {

	@Inject
	protected IConstraintFactory constraintFactory;
	
	override linkModel(EObject model, IDiagnosticConsumer diagnosticsConsumer) {
		val constraints = constraintFactory.create(model);
		println(constraints);
		
		super.linkModel(model, diagnosticsConsumer)
	}
	
}
