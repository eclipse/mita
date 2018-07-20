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

package org.eclipse.mita.program.inferrer;

import org.eclipse.mita.base.types.Type;
import org.eclipse.mita.base.types.TypeSpecifier;
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer.InferenceResult;

public class OptionalTypeExtensions {

	public static final String OPTIONAL_TYPE_NAME = "optional";
	
	public TypeSpecifier getOptionalBaseType(TypeSpecifier result) {
		if (isOptional(result.getType()) && !result.getTypeArguments().isEmpty()) {
			return getOptionalBaseType(result.getTypeArguments().get(0));
		}
		return result;
	}
	
	public InferenceResult getOptionalBaseType(InferenceResult result) {
		if (isOptional(result.getType()) && !result.getBindings().isEmpty()) {
			return getOptionalBaseType(result.getBindings().get(0));
		}
		return result;
	}
	
	public boolean isOptional(Type type) {
		if (type != null) {
			return OPTIONAL_TYPE_NAME.equals(type.getName());
		}
		return false;
	}
}
