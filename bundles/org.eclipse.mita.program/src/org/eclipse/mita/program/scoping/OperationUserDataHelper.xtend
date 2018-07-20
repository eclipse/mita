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

package org.eclipse.mita.program.scoping

import com.google.inject.Inject
import java.util.List
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.Type
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer.InferenceResult
import org.eclipse.mita.base.types.typesystem.ITypeSystem
import org.eclipse.xtext.resource.IEObjectDescription

class OperationUserDataHelper {

	@Inject
	extension ITypeSystemInferrer inferrer;

	@Inject
	extension ITypeSystem typesystem;

	def List<Type> getParameterTypes(IEObjectDescription operation) {
		val rawTypesArray = operation.parameterTypeNames
		
		if(rawTypesArray !== null) {
			return rawTypesArray.map[ typesystem.getType(it) ]
		} else {
			val objOrProxy = operation.EObjectOrProxy;
			if(objOrProxy instanceof Operation) {
				if(!objOrProxy.eIsProxy) {
					return objOrProxy.parameters.map[ it.type ]
				}
			}
			return #[];
		}
	}
	
	def List<InferenceResult> getParameterInferenceResults(IEObjectDescription operation) {
		val objOrProxy = operation.EObjectOrProxy;
		if (objOrProxy instanceof Operation) {
			if (!objOrProxy.eIsProxy) {
				return objOrProxy.parameters.map[it.infer]
			}
		}
		return #[];
	}

	def getParameterTypeNames(IEObjectDescription description) {
		val params = description.getUserData(ProgramDslResourceDescriptionStrategy.OPERATION_PARAM_TYPES);
		if (params === null) {
			return null
		}
		return params.toArray
	}

	protected def toArray(String paramArrayAsString) {
		paramArrayAsString.replace("[", "").replace("]", "").split(", ")
	}
}
