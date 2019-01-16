package org.eclipse.mita.base.typesystem.infra

import com.google.inject.Inject
import com.google.inject.name.Named
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.emf.ecore.impl.BasicEObjectImpl
import org.eclipse.emf.ecore.impl.EObjectImpl
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.resource.impl.ResourceImpl
import org.eclipse.mita.base.scoping.BaseResourceDescriptionStrategy
import org.eclipse.mita.base.typesystem.serialization.SerializationAdapter
import org.eclipse.mita.base.typesystem.solver.ConstraintSolution
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.IConstraintSolver
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.util.GZipper
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.diagnostics.Severity
import org.eclipse.xtext.linking.lazy.LazyLinkingResource
import org.eclipse.xtext.mwe.ResourceDescriptionsProvider
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.resource.IContainer
import org.eclipse.xtext.resource.impl.ListBasedDiagnosticConsumer
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.util.Triple
import org.eclipse.xtext.validation.EObjectDiagnosticImpl

import static extension org.eclipse.mita.base.util.BaseUtils.force

//class MitaBaseResource extends XtextResource {
class MitaBaseResource extends LazyLinkingResource {
	@Accessors
	protected ConstraintSolution latestSolution;
	@Accessors	
	protected MitaCancelInidicator cancelIndicator;
	
	
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

	new() {
		super();
		mkCancelIndicator();
	}
	
	override protected getEObject(String uriFragment, Triple<EObject, EReference, INode> triple) throws AssertionError {
		var model = triple.first;
		while (model.eContainer !== null) {
			model = model.eContainer;
		}

		val diagnosticsConsumer = new ListBasedDiagnosticConsumer();		
		typeLinker.doActuallyClearReferences(model);
		typeLinker.linkModel(model, diagnosticsConsumer);
		typeDependentLinker.linkModel(model, diagnosticsConsumer);
		collectAndSolveTypes(model);

		super.getEObject(uriFragment, triple)
	}
	
	def MitaCancelInidicator mkCancelIndicator() {
		cancelIndicator = new MitaCancelInidicator();
		return cancelIndicator;
	}
	
	static class MitaCancelInidicator implements CancelIndicator {
		public boolean canceled = false;
		override isCanceled() {
			return canceled;
		}
	}
	
	
	protected def resolveProxy(Resource resource, EObject obj) {
		(if(obj !== null && obj.eIsProxy) {
			if(obj instanceof EObjectImpl) {
				val uri = obj.eProxyURI;
				resource.resourceSet.getEObject(uri, true);
			}
		}) ?: obj;
	}
	
	def collectAndSolveTypes(EObject obj) {
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
		
		val cancelIndicator = if(resource instanceof MitaBaseResource) {
			resource.mkCancelIndicator();
		}
		
		val exportedObjects = /*thisExportedObjects + */(visibleContainers
			.flatMap[ it.exportedObjects ].force);
		val allConstraintSystems = exportedObjects
			.map[ it.EObjectURI -> it.getUserData(BaseResourceDescriptionStrategy.CONSTRAINTS) ]
			.map[it.value]
			.filterNull
			.map[GZipper.decompress(it)]
			.map[ constraintSerializationAdapter.deserializeConstraintSystemFromJSON(it, [ resource.resourceSet.getEObject(it, true) ]) ]
			.indexed.map[it.value.modifyNames('''.«it.key»''')].force;
		
		if(cancelIndicator !== null && cancelIndicator.canceled) {
			return;
		}
		
		if(obj.eResource.URI.lastSegment == "application.mita") {
			print("")
		}
		val combinedSystem = ConstraintSystem.combine(allConstraintSystems);
		
		if(combinedSystem !== null) {
			val preparedSystem = combinedSystem.replaceProxies(resource, scopeProvider);
			if(cancelIndicator !== null && cancelIndicator.canceled) {
				return;
			}
			
			val solution = constraintSolver.solve(preparedSystem, obj);
			if(solution !== null) {
				if(resource instanceof MitaBaseResource) {
					resource.latestSolution = solution;
					resource.cancelIndicator.canceled = true;
					resource.errors += solution.issues.filter[it.target !== null].toSet.filter[it.severity == Severity.ERROR].map[
						new EObjectDiagnosticImpl(it.severity, it.issueCode, it.message, resolveProxy(resource, it.target) ?: obj, it.feature, 0, #[]);
					]
					resource.warnings += solution.issues.filter[it.target !== null].toSet.filter[it.severity == Severity.WARNING].map[
						new EObjectDiagnosticImpl(it.severity, it.issueCode, it.message, resolveProxy(resource, it.target) ?: obj, it.feature, 0, #[]);
					]
					resource.warnings += solution.issues.filter[it.target !== null].toSet.filter[it.severity == Severity.INFO].map[
						new EObjectDiagnosticImpl(it.severity, it.issueCode, it.message, resolveProxy(resource, it.target) ?: obj, it.feature, 0, #[]);
					]
				}
			}
			if(solution !== null && solution.solution !== null) {
				if(obj.eResource.URI.lastSegment == "application.mita") {
					print("")
				}
				solution.solution.substitutions.entrySet.forEach[
					var origin = it.key.origin;
					if(origin !== null && origin.eIsProxy) {
						origin = resource.resourceSet.getEObject((origin as BasicEObjectImpl).eProxyURI, false);
					}
					
					if(origin !== null) {
						val type = it.value;
						// we had the object loaded anyways, so we can set the type
						TypeAdapter.set(origin, type);
						
						if(type instanceof BottomType) {
							resource.errors.add(new EObjectDiagnosticImpl(Severity.ERROR, "bottom_type", type.message, resolveProxy(resource, type.origin) ?: obj, null, 0, #[]));
						}
					}
				]				
			}
		}
	}
	
}
