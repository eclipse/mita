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
import org.eclipse.xtext.resource.IEObjectDescription
import org.yakindu.base.types.Operation
import org.yakindu.base.types.Type
import org.yakindu.base.types.typesystem.ITypeSystem

class OperationUserDataHelper {

	@Inject
	extension ITypeSystem typesystem;

	def List<Type> getArgumentTypes(IEObjectDescription operation) {
		val rawTypesArray = operation.typesArray
		
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
	
	def isCallable(IEObjectDescription it, List<Type> arguments) {
		val paramArray = getTypesArray
		if (paramArray.length == 0) {
			return false
		}
		
		println("ParamArray " + paramArray)
		println("arguments " + arguments)
		
		return true;
	}

	def isExtensionTo(IEObjectDescription it, Type contextType) {
		val paramArray = getTypesArray
		if (paramArray === null) {
			return false
		}
		val paramTypeName = paramArray.get(0)
		return contextType.isSubtypeOf(paramTypeName)
	}

	protected def getTypesArray(IEObjectDescription description) {
		val params = description.getUserData(ProgramDslResourceDescriptionStrategy.OPERATION_PARAM_TYPES);
		if (params === null) {
			return null
		}
		return params.toArray
	}

	protected def isSubtypeOf(Type subType, String superTypeName) {
		if (subType.name == superTypeName) {
			return true
		}
		val match = subType.superTypes.findFirst[name == superTypeName]
		return match !== null
	}

	protected def toArray(String paramArrayAsString) {
		paramArrayAsString.replace("[", "").replace("]", "").split(", ")
	}
}
