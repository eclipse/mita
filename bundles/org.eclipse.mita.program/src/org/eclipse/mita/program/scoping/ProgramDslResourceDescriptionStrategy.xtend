/** 
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 * Contributors:
 * Bosch Connected Devices and Solutions GmbH - initial contribution
 * SPDX-License-Identifier: EPL-2.0
 */
package org.eclipse.mita.program.scoping

import com.google.common.collect.ImmutableList
import java.util.Arrays
import java.util.Map
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.scoping.BaseResourceDescriptionStrategy
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.program.ProgramPackage

class ProgramDslResourceDescriptionStrategy extends BaseResourceDescriptionStrategy {
	public static final String OPERATION_PARAM_TYPES = "OPERATION_PARAM_TYPES"
	ImmutableList<EClass> SUPPRESSED_OBJECTS = ImmutableList.of(ProgramPackage.Literals.VARIABLE_DECLARATION)

	override protected boolean shouldCreateDescription(EObject object) {
		return !(SUPPRESSED_OBJECTS.contains(object.eClass()))
	}

	override void defineUserData(EObject eObject, Map<String, String> userData) {
		if (eObject instanceof Operation) {
			userData.put(OPERATION_PARAM_TYPES, Arrays.toString(getOperationParameterTypes((eObject as Operation))))
		}
		super.defineUserData(eObject, userData)
	}

	def static String[] getOperationParameterTypes(Operation operation) {
		var String[] paramTypes = newArrayOfSize(operation.getParameters().size())
		for (var int i = 0; i < operation.getParameters().size(); i++) {
			{
				val _wrVal_paramTypes = paramTypes
				val _wrIndx_paramTypes = i
				_wrVal_paramTypes.set(_wrIndx_paramTypes,
					getTypeSpecifierType(operation.getParameters().get(i).getTypeSpecifier()))
			}
		}
		return paramTypes
	}
}
