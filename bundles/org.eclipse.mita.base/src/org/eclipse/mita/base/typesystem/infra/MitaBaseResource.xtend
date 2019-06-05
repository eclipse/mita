/********************************************************************************
 * Copyright (c) 2018, 2019 Robert Bosch GmbH & TypeFox GmbH
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH & TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.base.typesystem.infra

import com.google.inject.Inject
import com.google.inject.name.Named
import java.io.IOException
import java.io.InputStream
import java.util.ArrayList
import java.util.Map
import org.apache.log4j.Logger
import org.eclipse.core.runtime.IProgressMonitor
import org.eclipse.core.runtime.Status
import org.eclipse.core.runtime.jobs.Job
import org.eclipse.emf.common.util.BasicEList
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.emf.ecore.impl.BasicEObjectImpl
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.resource.impl.ResourceImpl
import org.eclipse.mita.base.scoping.BaseResourceDescriptionStrategy
import org.eclipse.mita.base.types.GeneratedObject
import org.eclipse.mita.base.types.NullTypeSpecifier
import org.eclipse.mita.base.types.PackageAssociation
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.serialization.SerializationAdapter
import org.eclipse.mita.base.typesystem.solver.ConstraintSolution
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.IConstraintSolver
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.base.util.DebugTimer
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.diagnostics.Severity
import org.eclipse.xtext.linking.lazy.LazyLinkingResource
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.resource.IContainer
import org.eclipse.xtext.resource.IFragmentProvider
import org.eclipse.xtext.resource.impl.ListBasedDiagnosticConsumer
import org.eclipse.xtext.resource.impl.ResourceDescriptionsProvider
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.util.Triple
import org.eclipse.xtext.xtext.XtextFragmentProvider

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

	@Inject
	protected XtextFragmentProvider fragmentProvider;
	
	@Inject
	protected AbstractSizeInferrer sizeInferrer;

	override toString() {
		val str = URI.toString;
		val len = str.length();
		val maxLen = 30;
		val startIdx = if (len > maxLen) {
				len - maxLen;
			} else {
				0;
			}
		return URI.toString.substring(startIdx);
	}

	override protected doLoad(InputStream inputStream, Map<?, ?> options) throws IOException {
		super.doLoad(inputStream, options)

		BaseUtils.ignoreChange(this, [|
			contents.get(0).eAllContents.filter(GeneratedObject).forEach [
				it.generateMembers()
			]
			return;
		])
	}

	protected IFragmentProvider.Fallback fragmentProviderFallback = new IFragmentProvider.Fallback() {

		public override getFragment(EObject obj) {
			return MitaBaseResource.super.getURIFragment(obj);
		}

		public override getEObject(String fragment) {
			return MitaBaseResource.super.getEObject(fragment);
		}
	};

	new() {
		super();
		if (this.errors === null) {
			this.errors = new BasicEList();
		}
		if (this.warnings === null) {
			this.warnings = new BasicEList();
		}
		mkCancelIndicator();
	}


	private static Logger log = Logger.getLogger(LazyLinkingResource);
	override protected getEObject(String uriFragment, Triple<EObject, EReference, INode> triple) throws AssertionError {
		var model = triple.first;
		while (model.eContainer !== null) {
			model = model.eContainer;
		}
		
		generateLinkAndType(model);

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

	public static def resolveProxy(Resource resource, EObject obj) {
		(if (obj !== null && obj.eIsProxy) {
			if (obj instanceof BasicEObjectImpl) {
				val uri = obj.eProxyURI;
				resource.resourceSet.getEObject(uri, true);
			}
		}) ?: obj;
	}

	public def generateLinkAndType(EObject model) {
		val diagnosticsConsumer = new ListBasedDiagnosticConsumer();
		model.eAllContents.filter(GeneratedObject).forEach [
			it.generateMembers()
		]
		typeLinker.doActuallyClearReferences(model);
		typeLinker.linkModel(model, diagnosticsConsumer);
		typeDependentLinker.linkModel(model, diagnosticsConsumer);

		collectAndSolveTypes(model);
	}

	public def collectAndSolveTypes(EObject obj) {
		val timer = new DebugTimer(false);
		// top level element - gather constraints and solve
		val resource = obj.eResource;
		val resourceSet = resource.resourceSet;
		val errors = if (resource instanceof ResourceImpl) {
				resource.errors;
			}
		if (!errors.nullOrEmpty) {
			return;
		}

		timer.start("resourceDescriptions");
		if (!resourceSet.loadOptions.containsKey(ResourceDescriptionsProvider.NAMED_BUILDER_SCOPE)) {
			resourceSet.loadOptions.put(ResourceDescriptionsProvider.LIVE_SCOPE, true);
		}
		val resourceDescriptions = resourceDescriptionsProvider.getResourceDescriptions(resourceSet);
		val thisResourceDescription = resourceDescriptions.getResourceDescription(resource.URI);
		if (thisResourceDescription === null) {
			return;
		}

		val visibleContainers = containerManager.getVisibleContainers(thisResourceDescription, resourceDescriptions);

		val cancelIndicator = if (resource instanceof MitaBaseResource) {
				resource.mkCancelIndicator();
			}

		val visibleResources = visibleContainers.flatMap[it?.exportedObjects].map[it?.EObjectOrProxy?.eResource].groupBy [
			it?.URI
		].keySet.force;

		val exportedObjects = (visibleContainers.flatMap [
			it.exportedObjects
		].force);
		val jsons = exportedObjects.map [
			if (it.EObjectURI.toString.contains("stdlib_print")) {
				print("")
			}
			it.EObjectURI -> it.getUserData(BaseResourceDescriptionStrategy.CONSTRAINTS)
		].filter[it.value !== null].groupBy[it.key].values.map[it.head.value]// .map[GZipper.decompress(it)]
		.force;
		timer.stop("resourceDescriptions");
		timer.start("deserialize");
		val allConstraintSystems = jsons.map [
			constraintSerializationAdapter.deserializeConstraintSystemFromJSON(it, [
				val res = resource.resourceSet.getEObject(it, true);
				return res;
//				val resourceOfObj = resource.resourceSet.getResource(it.trimFragment, true);
//				return fragmentProvider.getEObject(resourceOfObj, it.fragment, fragmentProviderFallback);
			])
		]
		.map[it.instanceCount -> it]
		// calculate a running sum over all sizes
		.fold(new ArrayList<Pair<Integer, ConstraintSystem>>() as Iterable<Pair<Integer, ConstraintSystem>> -> 0,
			// given the old list and a running sum, and a constraint system with its size 
			[lst_runningSize, size_constraints | 
				// calculate the new running sum
				val nextSum = (lst_runningSize.value + size_constraints.key);
				// concatenate it to the input list, setting the offset to the current sum, and return both the list and the next running sum
				return (lst_runningSize.key + #[lst_runningSize.value -> size_constraints.value]) -> nextSum
			]
		)
		.key.map[it.value.modifyNames(it.key)].force;
		timer.stop("deserialize");
		if (cancelIndicator !== null && cancelIndicator.canceled) {
			return;
		}

		timer.start("combine");
		val combinedSystem = ConstraintSystem.combine(allConstraintSystems);
		timer.stop("combine");

		if (combinedSystem !== null) {
			timer.start("proxies");
			val preparedSystem = combinedSystem.replaceProxies(resource, scopeProvider);
			timer.stop("proxies");
			if (cancelIndicator !== null && cancelIndicator.canceled) {
				return;
			}
			timer.start("solve");
			val solutionTypes = constraintSolver.solve(preparedSystem, obj);
			timer.stop("solve");
			timer.start("size-inference");
			val solution = sizeInferrer.inferSizes(solutionTypes, this);
			timer.stop("size-inference");
			println("report for:" + resource.URI.lastSegment + "\n" + timer.toString);
			if (solution !== null) {
				solution.constraintSystem.coercions.entrySet.filter [
					val resourceUri = it.key.trimFragment;
					return resourceUri == resource.URI;
				].forEach [
					val coercedObj = resource.resourceSet.getEObject(it.key, false);
					if (coercedObj !== null) {
						var adapter = obj.eAdapters.filter(CoercionAdapter).head;
						if (adapter === null) {
							adapter = new CoercionAdapter;
							obj.eAdapters.add(adapter);
						}
						adapter.type = it.value;
					}
				]

				if (resource instanceof MitaBaseResource) {
					solution.constraintSystem.symbolTable.entrySet.forEach [
						val uri = it.key;
						if (uri.trimFragment == resource.URI) {
							val tv = it.value;
							val type = solution.solution.content.getOrDefault(tv.idx, tv);
							val origin = resource.resourceSet.getEObject(uri, false);
							if (origin !== null) {
								// we had the object loaded anyways, so we can set the type
								TypeAdapter.set(origin, type);
							}
							if (type instanceof BottomType) {
								val Pair<EObject, EStructuralFeature> errorSource = if (origin !== null &&
										origin.eResource == obj.eResource) {
										if (origin instanceof NullTypeSpecifier) {
											origin.eContainer -> type.feature;
										} else {
											origin -> type.feature;
										}
									} else if (obj instanceof PackageAssociation) {
										obj as EObject ->
											TypesPackage.eINSTANCE.packageAssociation_Name as EStructuralFeature;
									}
								if (errorSource !== null) {
									solution.issues +=
										new ValidationIssue(Severity.ERROR, type.message, errorSource.key,
											errorSource.value, "");
								}
							}
						}
					]

					resource.latestSolution = solution;
					resource.cancelIndicator.canceled = true;
				}
			}
		}
	}

}
