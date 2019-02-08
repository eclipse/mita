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

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult

class ReferenceSizeInferrer extends ElementSizeInferrer {
	
	override inferFromType(EObject obj, AbstractType type) {
		if(type instanceof TypeConstructorType) {
			if(type.name == "reference") {
				val result = new ValidElementSizeInferenceResult(obj, type, 1);
				return result;
			}
		}
		
		return super.inferFromType(obj, type);
	}	
}