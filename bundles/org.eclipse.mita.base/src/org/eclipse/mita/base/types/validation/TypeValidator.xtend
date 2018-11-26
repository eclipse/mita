/** 
 * Copyright (c) 2015 committers of YAKINDU and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * Contributors:
 * committers of YAKINDU - initial API and implementation
 */
package org.eclipse.mita.base.types.validation

import com.google.inject.Inject
import java.util.List
import org.eclipse.mita.base.types.ComplexType
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer.InferenceResult
import org.eclipse.mita.base.types.typesystem.ITypeSystem
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.xtext.diagnostics.Severity

import static org.eclipse.mita.base.types.inferrer.AbstractTypeSystemInferrer.ASSERT_COMPATIBLE
import static org.eclipse.mita.base.types.inferrer.AbstractTypeSystemInferrer.ASSERT_NOT_TYPE
import static org.eclipse.mita.base.types.inferrer.AbstractTypeSystemInferrer.ASSERT_SAME
import static org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer.NOT_COMPATIBLE_CODE
import static org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer.NOT_SAME_CODE
import static org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer.NOT_TYPE_CODE

class TypeValidator {
	@Inject protected ITypeSystem registry

	def void assertNotType(InferenceResult currentResult, String msg_finalParam_, IValidationIssueAcceptor acceptor,
		InferenceResult... candidates) {
		var msg = msg_finalParam_
		if(currentResult === null) return;
		for (InferenceResult type : candidates) {
			if (registry.isSame(currentResult.getType(), type.getType())) {
				msg = if(msg !== null) msg else String.format(ASSERT_NOT_TYPE, currentResult)
				acceptor.accept(new ValidationIssue(Severity.ERROR, msg, NOT_TYPE_CODE))
			}
		}
	}

	def void assertSame(InferenceResult result1, InferenceResult result2, String msg_finalParam_,
		IValidationIssueAcceptor acceptor) {
		var msg = msg_finalParam_
		if(result1 === null || result2 === null) return;
		if (!registry.isSame(result1.getType(), result2.getType())) {
			msg = if(msg !== null) msg else String.format(ASSERT_SAME, result1, result2)
			acceptor.accept(new ValidationIssue(Severity.ERROR, msg, NOT_SAME_CODE))
			return;
		}
		assertTypeBindingsSame(result1, result2, msg, acceptor)
	}

	def void assertCompatible(InferenceResult result1, InferenceResult result2, String msg_finalParam_,
		IValidationIssueAcceptor acceptor) {
		var msg = msg_finalParam_
		if (result1 === null || result2 === null || isNullOnComplexType(result1, result2) ||
			isNullOnComplexType(result2, result1)) {
			return;
		}
		if (!registry.haveCommonType(result1.getType(), result2.getType())) {
			msg = if(msg !== null) msg else String.format(ASSERT_COMPATIBLE, result1, result2)
			acceptor.accept(new ValidationIssue(Severity.ERROR, msg, NOT_COMPATIBLE_CODE))
			return;
		}
		assertTypeBindingsSame(result1, result2, msg, acceptor)
	}

	def void assertAssignable(InferenceResult varResult, InferenceResult valueResult, String msg_finalParam_,
		IValidationIssueAcceptor acceptor) {
		var msg = msg_finalParam_
		if (varResult === null || valueResult === null || isNullOnComplexType(varResult, valueResult)) {
			return;
		}
		if (!registry.isSuperType(valueResult.getType(), varResult.getType())) {
			msg = if(msg !== null) msg else String.format(ASSERT_COMPATIBLE, varResult, valueResult)
			acceptor.accept(new ValidationIssue(Severity.ERROR, msg, NOT_COMPATIBLE_CODE))
			return;
		}
		assertTypeBindingsSame(varResult, valueResult, msg, acceptor)
	}

	def void assertTypeBindingsSame(InferenceResult result1, InferenceResult result2, String msg_finalParam_,
		IValidationIssueAcceptor acceptor) {
		var msg = msg_finalParam_
		var List<InferenceResult> bindings1 = result1.getBindings()
		var List<InferenceResult> bindings2 = result2.getBindings()
		msg = if(msg !== null) msg else String.format(ASSERT_COMPATIBLE, result1, result2)
		if (bindings1.size() !== bindings2.size()) {
			acceptor.accept(new ValidationIssue(Severity.ERROR, msg, NOT_COMPATIBLE_CODE))
			return;
		}
		for (var int i = 0; i < bindings1.size(); i++) {
			assertSame(bindings1.get(i), bindings2.get(i), msg, acceptor)
		}
	}

	def void assertIsSubType(InferenceResult subResult, InferenceResult superResult, String msg_finalParam_,
		IValidationIssueAcceptor acceptor) {
		var msg = msg_finalParam_
		if(subResult === null || superResult === null) return;
		if (!registry.isSuperType(subResult.getType(), superResult.getType())) {
			msg = if(msg !== null) msg else String.format(ASSERT_COMPATIBLE, subResult, superResult)
			acceptor.accept(new ValidationIssue(Severity.ERROR, msg, NOT_COMPATIBLE_CODE))
		}
	}

	def boolean isNullOnComplexType(InferenceResult result1, InferenceResult result2) {
		return result1.getType() instanceof ComplexType &&
			registry.isSame(result2.getType(), registry.getType(ITypeSystem.NULL))
	}
}
