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

import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult
import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer.InferenceResult
import org.eclipse.mita.base.types.typesystem.ITypeSystem
import org.eclipse.mita.program.model.ModelUtils

class ReferenceSizeInferrer extends ElementSizeInferrer {
	
	@Inject
	protected ITypeSystem registry;
	
	protected override dispatch doInfer(EObject obj) {
		return new ValidElementSizeInferenceResult(obj, ModelUtils.toSpecifier(InferenceResult.from(registry.getType("int32"))), 1);
	}
	
}