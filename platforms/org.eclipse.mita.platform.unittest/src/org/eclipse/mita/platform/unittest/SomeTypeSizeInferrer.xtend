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

import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.inferrer.InvalidElementSizeInferenceResult
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.VariableDeclaration

class SomeTypeSizeInferrer extends ElementSizeInferrer {
	
	override protected dispatch doInfer(NewInstanceExpression obj) {
		val parentType = ModelUtils.toSpecifier(typeInferrer.infer(obj.eContainer));

		if(parentType === null) {
			return new InvalidElementSizeInferenceResult(obj, parentType, "parent type unknown");
		} else {
			val staticSizeValue = 1;
			val typeOfChildren = parentType.typeArguments.head;
			val result = new ValidElementSizeInferenceResult(obj, parentType, staticSizeValue as Integer);
			result.children.add(super.infer(typeOfChildren));
			return result;
		}
	}
		
	override protected dispatch doInfer(VariableDeclaration obj) {
		return newValidResult(obj, 0);
	}
	
}
