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

import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.inferrer.InvalidElementSizeInferenceResult
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult

class SomeTypeSizeInferrer extends ElementSizeInferrer {
	
	override protected dispatch doInfer(NewInstanceExpression obj, AbstractType type) {
		val parentType = BaseUtils.getType(obj.eContainer);

		if(parentType instanceof TypeVariable || parentType instanceof BottomType) {
			return new InvalidElementSizeInferenceResult(obj, parentType, "parent type unknown: " + parentType);
		} else {
			val staticSizeValue = 1;
			val typeOfChildren = (parentType as TypeConstructorType).typeArguments.head;
			val result = new ValidElementSizeInferenceResult(obj, parentType, staticSizeValue as Integer);
			result.children.add(super.inferFromType(typeOfChildren.origin, typeOfChildren));
			return result;
		}
	}
		
	override protected dispatch doInfer(VariableDeclaration obj, AbstractType type) {
		return newValidResult(obj, 0);
	}
	
}
