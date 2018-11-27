package org.eclipse.mita.base.typesystem.infra

import com.google.inject.name.Named
import javax.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.impl.BasicEObjectImpl
import org.eclipse.emf.ecore.impl.EObjectImpl
import org.eclipse.emf.ecore.resource.impl.ResourceImpl
import org.eclipse.mita.base.scoping.BaseResourceDescriptionStrategy
import org.eclipse.mita.base.types.GeneratedObject
import org.eclipse.mita.base.typesystem.serialization.SerializationAdapter
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.IConstraintSolver
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.base.util.GZipper
import org.eclipse.xtext.diagnostics.IDiagnosticConsumer
import org.eclipse.xtext.diagnostics.IDiagnosticProducer
import org.eclipse.xtext.linking.impl.Linker
import org.eclipse.xtext.mwe.ResourceDescriptionsProvider
import org.eclipse.xtext.resource.IContainer
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.xtext.validation.EObjectDiagnosticImpl

import static extension org.eclipse.mita.base.util.BaseUtils.force
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.diagnostics.Severity

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
	
	@Inject @Named("typeLinker")
	protected MitaTypeLinker typeLinker;
	
	@Inject @Named("typeDependentLinker")
	protected MitaTypeLinker typeDependentLinker;

	override linkModel(EObject model, IDiagnosticConsumer diagnosticsConsumer) {
		typeLinker.linkModel(model, diagnosticsConsumer);
		typeDependentLinker.linkModel(model, diagnosticsConsumer);
		super.linkModel(model, diagnosticsConsumer);
	}

	override ensureLinked(EObject obj, IDiagnosticProducer producer) {
		if(obj.eContainer === null) {
			BaseUtils.ignoreChange(obj,  [
				obj.eAllContents.filter(GeneratedObject).forEach[it.generateMembers()]
			]);
			collectAndSolveTypes(obj, producer);
		}
		
		//super.ensureLinked(obj, producer)
	}
	
	def resolveProxy(Resource resource, EObject obj) {
		(if(obj !== null && obj.eIsProxy) {
			if(obj instanceof EObjectImpl) {
				val uri = obj.eProxyURI;
				resource.resourceSet.getEObject(uri, true);
			}
		}) ?: obj;
	}
	
	def collectAndSolveTypes(EObject obj, IDiagnosticProducer producer) {
		// top level element - gather constraints and solve
		val resource = obj.eResource;
		val errors = if(resource instanceof ResourceImpl) {
			resource.errors;
		}
		if(!errors.nullOrEmpty) {
			return;
		}
		
		val resourceDescriptions = resourceDescriptionsProvider.get(resource.resourceSet);
		val thisResourceDescription = resourceDescriptions.getResourceDescription(resource.URI);
		val visibleContainers = containerManager.getVisibleContainers(thisResourceDescription, resourceDescriptions);
		
		
		val exportedObjects = /*thisExportedObjects + */(visibleContainers
			.flatMap[ it.exportedObjects ].force);
		val allConstraintSystems = exportedObjects
			.map[ it.EObjectURI -> it.getUserData(BaseResourceDescriptionStrategy.CONSTRAINTS) ]
			.filter[it.value !== null]
			.map[it.value]
			.map[GZipper.decompress(it)]
			.map[ constraintSerializationAdapter.deserializeConstraintSystemFromJSON(it, [ resource.resourceSet.getEObject(it, true) ]) ]
			.indexed.map[it.value.modifyNames('''.«it.key»''')].force;
			
		val combinedSystem = ConstraintSystem.combine(allConstraintSystems);
		
		if(combinedSystem !== null) {
			val preparedSystem = combinedSystem.replaceProxies(resource, scopeProvider);
			if(obj.eResource.URI.lastSegment == "application.mita") {
				print("")
			}
			if(resource instanceof MitaBaseResource) {
				resource.mkCancelIndicator();
			}
			
			
			val solution = constraintSolver.solve(preparedSystem, obj);
			if(solution !== null) {
				if(resource instanceof MitaBaseResource) {
					resource.latestSolution = solution;
					resource.cancelIndicator.canceled = true;
					resource.errors += solution.issues.filter[it.target !== null].filter[it.severity == Severity.ERROR].map[
						new EObjectDiagnosticImpl(it.severity, it.issueCode, it.message, resolveProxy(resource, it.target) ?: obj, it.feature, 0, #[]);
					]
					resource.warnings += solution.issues.filter[it.target !== null].filter[it.severity == Severity.WARNING].map[
						new EObjectDiagnosticImpl(it.severity, it.issueCode, it.message, resolveProxy(resource, it.target) ?: obj, it.feature, 0, #[]);
					]
					resource.warnings += solution.issues.filter[it.target !== null].filter[it.severity == Severity.INFO].map[
						new EObjectDiagnosticImpl(it.severity, it.issueCode, it.message, resolveProxy(resource, it.target) ?: obj, it.feature, 0, #[]);
					]
				}
			}
			if(solution !== null && solution.solution !== null) {
				solution.solution.substitutions.entrySet.forEach[
					var origin = it.key.origin;
					if(origin !== null && origin.eIsProxy) {
						origin = resource.resourceSet.getEObject((origin as BasicEObjectImpl).eProxyURI, false);
					}
					
					if(origin !== null) {
						val type = it.value;
						// we had the object loaded anyways, so we can set the type
						TypeAdapter.set(origin, type);
						
//						if(type instanceof BottomType) {
//							producer.addDiagnostic( new DiagnosticMessage(type.message, Severity.ERROR, "bottomType"));
//						}
					}
				]				
			}
		}
	}

	override protected clearReferences(EObject obj) {
		return;
	}
	
}
