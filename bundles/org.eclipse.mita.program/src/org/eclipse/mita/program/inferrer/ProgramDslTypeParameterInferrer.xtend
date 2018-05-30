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

package org.eclipse.mita.program.inferrer

import com.google.inject.Inject
import java.util.Map
import org.eclipse.mita.base.expressions.inferrer.TypeParameterInferrer
import org.eclipse.mita.base.types.TypeParameter
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer.InferenceResult
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor

class ProgramDslTypeParameterInferrer extends TypeParameterInferrer {
	
	@Inject
	extension OptionalTypeExtensions
	
	override assertArgumentAndParameterSoftCompatible(InferenceResult argumentResult, TypeSpecifier parameter,
			IValidationIssueAcceptor acceptor) {
		
		// do not check soft compatibility for optional types as optional<integer> and integer should be compatible
		if (parameter.type.isOptional || argumentResult.type.isOptional) {
			return;
		}
		super.assertArgumentAndParameterSoftCompatible(argumentResult, parameter, acceptor);
	}
	
	override parameterContainsTypeParameter(TypeSpecifier specifier) {
		return super.parameterContainsTypeParameter(specifier.getOptionalBaseType)
	}
	
	override inferTypeParametersFromOwner(InferenceResult operationOwnerResult, Map<TypeParameter, InferenceResult> inferredTypeParameterTypes) {
		// safeguard against NPE in super
		if(operationOwnerResult?.type === null) return;
		
		super.inferTypeParametersFromOwner(operationOwnerResult, inferredTypeParameterTypes)
	}
	
}