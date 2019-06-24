/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.library.stdlib

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.types.TypeReferenceSpecifier
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.program.resource.PluginResourceLoader
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull;
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.base.typesystem.infra.InferenceContext

class VirtualTypeSizeInferrer extends GenericContainerSizeInferrer {
	// implements inference for modality and siginst
	@Inject
	protected PluginResourceLoader loader;
	
	override unbindSize(Resource r, ConstraintSystem system, EObject obj, AbstractType type) {
		super.unbindSize(r, system, obj, type)
	}
	
	dispatch def Pair<AbstractType, Iterable<EObject>> doUnbindSize(Resource r, ConstraintSystem system, ElementReferenceExpression obj, TypeConstructorType type) {
		val superResult = super._doUnbindSize(r, system, obj, type);
		if(type.name == "siginst") {
			val sigInst = obj.reference?.castOrNull(SignalInstance); 
			
			return superResult.key -> (superResult.value + #[sigInst]);
		}
		
		return superResult;
	}
	
//	// siginsts are on SignalInstances
//	protected dispatch def Optional<InferenceContext> doInfer(InferenceContext c, ElementReferenceExpression ref, TypeConstructorType type) {
//		val obj = ref.eContainer;
//		if(obj instanceof SignalInstance) {
//			// call platform inferrer
//			val resource = (obj.eContainer as SystemResourceSetup).type;
//			val sizeInferrerCls = resource.sizeInferrer;
//			val sizeInferrer = loader.loadFromPlugin(c.r, sizeInferrerCls)?.castOrNull(ElementSizeInferrer);
//			if(sizeInferrer === null) {
//				c.sub.add(c.tv, new BottomType(obj, '''«obj.name» does not specify a size inferrer'''));
//				return Optional.absent;
//			}
//			sizeInferrer.delegate = this;
//			val inferenceResult = sizeInferrer.createConstraints(new InferenceContext(c, obj, getDataType(type)));
//			return inferenceResult;	
//		}
//		return delegate.createConstraints(c);
//	}
//	
//	// call delegate for other things
//	protected dispatch def Optional<InferenceContext> doInfer(InferenceContext c, EObject obj, TypeConstructorType type) {
//		return delegate.createConstraints(c);
//	}
//	
//	// error/wait if type is not TypeConstructorType
//	protected dispatch def Optional<InferenceContext> doInfer(InferenceContext c, EObject obj, AbstractType type) {
//		return Optional.of(c);
//	}
//		
//	override max(ConstraintSystem system, Resource r, EObject objOrProxy, Iterable<AbstractType> types) {
//		if(types.size == 0 || !types.forall[it instanceof TypeConstructorType]) {
//			return Optional.absent;
//		}
//		val x = types.head as TypeConstructorType;
//		return delegate.max(system, r, objOrProxy, types.map[getDataType]).transform[
//			new TypeConstructorType(null, x.typeArguments.head, #[it -> Variance.INVARIANT])		
//		]
//	}
		
	override getDataTypeIndexes() {
		return #[1];
	}
	
	override getSizeTypeIndexes() {
		return #[];
	}
		
}