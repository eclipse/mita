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

import com.google.common.base.Optional
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.typesystem.infra.ElementSizeInferrer
import org.eclipse.mita.base.typesystem.infra.InferenceContext
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtend.lib.annotations.Accessors

class OptionalSizeInferrer implements ElementSizeInferrer {
	@Accessors
	ElementSizeInferrer delegate;
	
	
	override Optional<InferenceContext> infer(InferenceContext c) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override max(ConstraintSystem system, Resource r, EObject objOrProxy, Iterable<AbstractType> types) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
//	override protected dispatch doInfer(VariableDeclaration obj, AbstractType type) {
//		val result = obj.initialization?.infer;
//		if(result instanceof ValidElementSizeInferenceResult) { 
//			return result;	
//		}
//		if(type instanceof TypeConstructorType) {
//			val inner = type.typeArguments.tail.head;
//			if(type !== null) {
//				return new ValidElementSizeInferenceResult(obj, inner, 1);	
//			}	
//		}
//		return newInvalidResult(obj, "Cannot infer size for this optional, since I can't infer the type of it");
//		 
//	}
//	
//	override protected dispatch doInfer(ElementReferenceExpression obj, AbstractType type) {
//		if(obj.operationCall) {
//			val refFun = obj.reference;
//			val refType = BaseUtils.getType(refFun);
//			if(refFun instanceof GeneratedFunctionDefinition) {
//				if((refFun.name == "none" || refFun.name == "some") && refType?.name == "optional") {
//					return new ValidElementSizeInferenceResult(obj, refType, 1);
//				}
//			}
//		}
//		return super.infer(obj.reference)
//	}
//	
//	override protected dispatch doInfer(PrimitiveValueExpression obj, AbstractType type) {
//		val parentType = BaseUtils.getType(obj.eContainer);
//		if(parentType === null) {
//			return new InvalidElementSizeInferenceResult(obj, parentType, "parent type unknown");
//		} else {
//			return new ValidElementSizeInferenceResult(obj, parentType, 1);
//		}
//	}
//	
//	override protected dispatch doInferFromType(EObject obj, AbstractType type) {
//		if(type !== null) {
//			val res = new ValidElementSizeInferenceResult(obj, type, 1);
//			return res;
//		}
//		return super.inferFromType(obj, type);
//	}
	
}