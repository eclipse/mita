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
import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult

class ReferenceSizeInferrer extends ElementSizeInferrer {
	
	@Inject
	protected StdlibTypeRegistry typeRegistry;
	
	protected override dispatch doInfer(EObject obj) {
		return new ValidElementSizeInferenceResult(obj, typeRegistry.getIntegerTypes(obj).findFirst[it.name == "int32"], 1);
	}
	
}