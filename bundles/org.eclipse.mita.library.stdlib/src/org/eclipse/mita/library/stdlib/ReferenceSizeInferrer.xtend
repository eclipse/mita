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

import org.eclipse.mita.base.typesystem.infra.ElementSizeInferrer
import org.eclipse.mita.base.typesystem.infra.InferenceContext
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.constraints.MaxConstraint

class ReferenceSizeInferrer implements ElementSizeInferrer {
	
//	@Inject
//	protected StdlibTypeRegistry typeRegistry;
//	
//	protected dispatch def doInferFromType(EObject obj, TypeConstructorType type) {
//		if(type instanceof TypeConstructorType) {
//			if(type.name == "reference") {
//				return new ValidElementSizeInferenceResult(obj, type, 1);
//			}
//		}
//		return super.doInferFromType(obj, type);
//	}
	
	@Accessors
	ElementSizeInferrer delegate;
	
	// references are a safe border for sizes	
	override unbindSize(Resource r, ConstraintSystem system, EObject obj, AbstractType type) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	override createConstraints(InferenceContext c) {
		return;
	}
	
	override createConstraintsForMax(ConstraintSystem system, Resource r, MaxConstraint constraint) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
}