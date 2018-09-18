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
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.emf.ecore.impl.BasicEObjectImpl
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.xtext.diagnostics.DiagnosticMessage
import org.eclipse.xtext.diagnostics.Severity
import com.google.common.collect.Lists

class MitaLinker extends Linker {

	@Inject
	protected IConstraintSolver constraintSolver;
	
	@Inject
	protected IContainer.Manager containerManager;
	
	@Inject
	protected ResourceDescriptionsProvider resourceDescriptionsProvider;
	
	@Inject
	protected SerializationAdapter constraintSerializationAdapter;
	
	@Inject
	protected IScopeProvider scopeProvider;

	override ensureLinked(EObject obj, IDiagnosticProducer producer) {
		if(obj.eContainer === null) {
			collectAndSolveTypes(obj, producer);
		}
		
		super.ensureLinked(obj, producer)
	}
	
	def collectAndSolveTypes(EObject obj, IDiagnosticProducer producer) {
		// top level element - gather constraints and solve
		val resource = obj.eResource;
		val resourceDescriptions = resourceDescriptionsProvider.get(resource.resourceSet);
		val thisResourceDescription = resourceDescriptions.getResourceDescription(resource.URI);
		val visibleContainers = containerManager.getVisibleContainers(thisResourceDescription, resourceDescriptions);
		
		val allConstraintSystems = Lists.newArrayList(visibleContainers
			.flatMap[ it.exportedObjects ]
			.map[ it.getUserData(BaseResourceDescriptionStrategy.CONSTRAINTS) ]
			.filterNull
			.map[ constraintSerializationAdapter.fromJSON(it, [ resource.resourceSet.getEObject(it, true) ]) ]);
		val combinedSystem = ConstraintSystem.combine(allConstraintSystems);
		
		if(combinedSystem !== null) {
			combinedSystem.replaceProxies(scopeProvider);
			
			val solution = constraintSolver.solve(combinedSystem);
			if(solution !== null && solution.solution !== null) {
				solution.solution.substitutions.entrySet.forEach[
					var origin = it.key.origin;
					if(origin.eIsProxy) {
						origin = resource.resourceSet.getEObject((origin as BasicEObjectImpl).eProxyURI, false);
					}
					
					if(origin !== null) {
						val type = it.value;
						// we had the object loaded anyways, so we can set the type
						TypeAdapter.set(origin, type);
						
						if(type instanceof BottomType) {
							producer.addDiagnostic(new DiagnosticMessage(type.message, Severity.ERROR, "bottomType"));
						}
					}
				]				
			}
		}
	}

//	override protected isClearAllReferencesRequired(Resource resource) {
//		false
//	}
	
}
