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

package org.eclipse.mita.program.validation;

import org.yakindu.base.expressions.inferrer.ExpressionsTypeInferrer;
import org.yakindu.base.types.inferrer.ITypeSystemInferrer.InferenceResult;
import org.yakindu.base.types.typesystem.ITypeSystem;
import org.yakindu.base.types.validation.IValidationIssueAcceptor;
import org.yakindu.base.types.validation.TypeValidator;

import org.eclipse.mita.program.inferrer.OptionalTypeExtensions;
import com.google.inject.Inject;

/**
 * TODO: remove once inference of literals is more sophisticated in
 * {@link ExpressionsTypeInferrer}, see also
 * https://github.com/Yakindu/statecharts/issues/1313
 *
 */
public class ProgramDslTypeValidator extends TypeValidator {

	@Inject
	private OptionalTypeExtensions optionalTypeHelper;
	
	
	@Override
	public void assertAssignable(InferenceResult varResult, InferenceResult valueResult, String msg, IValidationIssueAcceptor acceptor) {
		if (varResult == null || valueResult == null) {
			return;
		}
		
		if (optionalTypeHelper.isOptional(varResult.getType()) && !optionalTypeHelper.isOptional(valueResult.getType())) {
			varResult = optionalTypeHelper.getOptionalBaseType(varResult);
		}
		
		if (isSuperTypeLiteralAssignment(varResult, valueResult, ITypeSystem.INTEGER) ||
			isValidRealLiteralAssignment(varResult, valueResult) ||
			isSuperTypeLiteralAssignment(varResult, valueResult, ITypeSystem.BOOLEAN) ||
			isSuperTypeLiteralAssignment(varResult, valueResult, ITypeSystem.STRING)) {
			return;
		}
		super.assertAssignable(varResult, valueResult, msg, acceptor);
	}

	@Override
	public void assertSame(InferenceResult result1, InferenceResult result2, String msg, IValidationIssueAcceptor acceptor) {
		if (result1 == null || result2 == null) {
			return;
		}
		
		if (isSuperTypeLiteralAssignment(result1, result2, ITypeSystem.INTEGER) ||
			isValidRealLiteralAssignment(result1, result2) ||
			isSuperTypeLiteralAssignment(result1, result2, ITypeSystem.BOOLEAN) ||
			isSuperTypeLiteralAssignment(result1, result2, ITypeSystem.STRING)) {
			return;
		}
		super.assertSame(result1, result2, msg, acceptor);
	}

	@Override
	public void assertCompatible(InferenceResult result1, InferenceResult result2, String msg, IValidationIssueAcceptor acceptor) {
		if (result1 == null || result2 == null) {
			return;
		}
		
		result1 = optionalTypeHelper.getOptionalBaseType(result1);
		result2 = optionalTypeHelper.getOptionalBaseType(result2);
		super.assertCompatible(result1, result2, msg, acceptor);
	}

	protected boolean isSuperTypeLiteralAssignment(InferenceResult varResult, InferenceResult valueResult, String literalTypeName) {
		return registry.isSame(valueResult.getType(), registry.getType(literalTypeName)) &&
			registry.isSuperType(varResult.getType(), registry.getType(literalTypeName));
	}

	protected boolean isValidRealLiteralAssignment(InferenceResult varResult, InferenceResult valueResult) {
		// integers are subtypes of real but we need to prohibit real assignments to integers
		return registry.isSuperType(valueResult.getType(), registry.getType(ITypeSystem.REAL)) &&
			registry.isSuperType(varResult.getType(), registry.getType(ITypeSystem.REAL)) &&
			!registry.isSuperType(varResult.getType(), registry.getType(ITypeSystem.INTEGER));
	}
}
