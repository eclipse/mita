package org.eclipse.mita.base.typesystem.infra

import javax.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.scoping.BaseResourceDescriptionStrategy
import org.eclipse.mita.base.typesystem.serialization.SerializationAdapter
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.IConstraintSolver
import org.eclipse.xtext.diagnostics.IDiagnosticProducer
import org.eclipse.xtext.linking.impl.Linker
import org.eclipse.xtext.mwe.ResourceDescriptionsProvider
import org.eclipse.xtext.resource.IContainer

class MitaLinker extends Linker {

	@Inject
	protected IConstraintSolver constraintSolver;
	
	@Inject
	protected IContainer.Manager containerManager;
	
	@Inject
	protected ResourceDescriptionsProvider resourceDescriptionsProvider;
	
	@Inject
	protected SerializationAdapter constraintSerializationAdapter;

	override ensureLinked(EObject obj, IDiagnosticProducer producer) {
		if(obj.eContainer === null) {
			// top level element - gather constraints and solve
			val resource = obj.eResource;
			val resourceDescriptions = resourceDescriptionsProvider.get(resource.resourceSet);
			val thisResourceDescription = resourceDescriptions.getResourceDescription(resource.URI);
			val visibleContainers = containerManager.getVisibleContainers(thisResourceDescription, resourceDescriptions);
			
			val allConstraintSystems = visibleContainers
				.flatMap[ it.exportedObjects ]
				.map[ it.getUserData(BaseResourceDescriptionStrategy.CONSTRAINTS) ]
				.filterNull
				.map[ constraintSerializationAdapter.fromJSON(it) ];
			val combinedSystem = ConstraintSystem.combine(allConstraintSystems);
			
			val forDebuggingOnly = resourceDescriptions.exportedObjects.toList();
			println(forDebuggingOnly);
			
			if(combinedSystem !== null) {
				// TODO: replace typevar proxies
				
				val solution = constraintSolver.solve(combinedSystem);
				println(solution);
				
				// TODO: attach solution to EObjects
			}
		}
		
		super.ensureLinked(obj, producer)
	}

//	override protected isClearAllReferencesRequired(Resource resource) {
//		false
//	}
	
}
