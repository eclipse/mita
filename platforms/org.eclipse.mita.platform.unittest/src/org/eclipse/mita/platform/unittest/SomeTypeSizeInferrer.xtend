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

package org.eclipse.mita.platform.unittest

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.typesystem.infra.ElementSizeInferrer
import org.eclipse.mita.base.typesystem.infra.InferenceContext
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.constraints.MaxConstraint

class SomeTypeSizeInferrer implements ElementSizeInferrer {
	@Accessors
	ElementSizeInferrer delegate;
	
	
	override void createConstraints(InferenceContext c) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
//	override max(ConstraintSystem system, Resource r, EObject objOrProxy, Iterable<AbstractType> types) {
//		throw new UnsupportedOperationException("TODO: auto-generated method stub")
//	}
	
	override unbindSize(Resource r, ConstraintSystem system, EObject obj, AbstractType type) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override createConstraintsForMax(ConstraintSystem system, Resource r, MaxConstraint constraint) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
//	override protected dispatch doInfer(NewInstanceExpression obj, AbstractType type) {
//		val parentType = BaseUtils.getType(obj.eContainer);
//
//		if(parentType instanceof TypeVariable || parentType instanceof BottomType) {
//			return new InvalidElementSizeInferenceResult(obj, parentType, "parent type unknown: " + parentType);
//		} else {
//			val staticSizeValue = 1;
//			val typeOfChildren = (parentType as TypeConstructorType).typeArguments.tail.head;
//			val result = new ValidElementSizeInferenceResult(obj, parentType, staticSizeValue as Integer);
//			result.children.add(super.inferFromType(typeOfChildren.origin, typeOfChildren));
//			return result;
//		}
//	}
//		
//	override protected dispatch doInfer(VariableDeclaration obj, AbstractType type) {
//		return newValidResult(obj, 0);
//	}
		
}
