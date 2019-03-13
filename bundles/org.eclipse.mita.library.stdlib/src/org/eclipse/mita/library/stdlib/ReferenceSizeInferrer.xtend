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

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult

class ReferenceSizeInferrer extends ElementSizeInferrer {
	
	@Inject
	protected StdlibTypeRegistry typeRegistry;
	
	protected dispatch def doInferFromType(EObject obj, TypeConstructorType type) {
		if(type instanceof TypeConstructorType) {
			if(type.name == "reference") {
				return new ValidElementSizeInferenceResult(obj, type, 1);
			}
		}
		return super.doInferFromType(obj, type);
	}
	
}