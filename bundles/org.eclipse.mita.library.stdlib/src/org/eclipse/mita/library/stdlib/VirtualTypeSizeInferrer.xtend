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
	
	// TODO modalities once we have any with dynamically sized types
	dispatch def Pair<AbstractType, Iterable<EObject>> doUnbindSize(Resource r, ConstraintSystem system, ElementReferenceExpression obj, TypeConstructorType type) {
		val superResult = super._doUnbindSize(r, system, obj, type);
		if(type.name == "siginst") {
			val sigInst = obj.reference?.castOrNull(SignalInstance); 
			
			return superResult.key -> (superResult.value + #[sigInst]);
		}
		
		return superResult;
	}
			
	override getDataTypeIndexes() {
		return #[1];
	}
	
	override getSizeTypeIndexes() {
		return #[];
	}
		
}