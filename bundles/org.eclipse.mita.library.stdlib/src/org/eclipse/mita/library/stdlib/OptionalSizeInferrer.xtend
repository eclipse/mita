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

import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.inferrer.InvalidElementSizeInferenceResult
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult
import org.eclipse.mita.program.model.ModelUtils
import com.google.inject.Inject
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.TypeSpecifier

class OptionalSizeInferrer extends ElementSizeInferrer {
	
	@Inject ITypeSystemInferrer typeInferrer;
	
	
	override protected dispatch doInfer(VariableDeclaration obj) {
		val result = obj.initialization?.infer;
		if(result instanceof ValidElementSizeInferenceResult) { 
			return result;	
		}
		val type = obj.typeSpecifier?.typeArguments?.get(0);
		if(type !== null) {
			return new ValidElementSizeInferenceResult(obj, type, 1);	
		}
		else {
			return newInvalidResult(obj, "Cannot infer size for this optional, since I can't infer the type of it");
		} 
	}
	
	override protected dispatch doInfer(ElementReferenceExpression obj) {
		if(obj.operationCall) {
			val refFun = obj.reference;
			val refType = typeInferrer.infer(refFun);
			if(refFun instanceof GeneratedFunctionDefinition) {
				if((refFun.name == "none" || refFun.name == "some") && refType?.type?.name == "optional") {
					return new ValidElementSizeInferenceResult(obj, ModelUtils.toSpecifier(refType), 1);
				}
			}
		}
		return super.infer(obj.reference)
	}
	
	override protected dispatch doInfer(PrimitiveValueExpression obj) {
		val parentType = ModelUtils.toSpecifier(typeInferrer.infer(obj.eContainer));
		if(parentType === null) {
			return new InvalidElementSizeInferenceResult(obj, parentType, "parent type unknown");
		} else {
			return new ValidElementSizeInferenceResult(obj, parentType, 1);
		}
	}
	
	override protected inferFromType(EObject obj, TypeSpecifier typeSpec) {
		if(typeSpec !== null) {
			val res = new ValidElementSizeInferenceResult(obj, typeSpec, 1);
			return res;
		}
		return super.inferFromType(obj, typeSpec);
	}
	
}