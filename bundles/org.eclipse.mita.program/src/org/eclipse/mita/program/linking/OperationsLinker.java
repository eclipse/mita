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

package org.eclipse.mita.program.linking;

import static com.google.common.collect.Lists.newArrayList;
import static com.google.common.collect.Lists.transform;

import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

import org.eclipse.mita.base.expressions.ArgumentExpression;
import org.eclipse.mita.base.expressions.Expression;
import org.eclipse.mita.base.expressions.util.ArgumentSorter;
import org.eclipse.mita.base.types.Operation;
import org.eclipse.mita.base.types.Type;
import org.eclipse.mita.base.types.TypesPackage;
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer;
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer.InferenceResult;
import org.eclipse.mita.base.types.typesystem.ITypeSystem;
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor;
import org.eclipse.mita.base.types.validation.TypeValidator;
import org.eclipse.mita.program.scoping.ExtensionMethodHelper;
import org.eclipse.mita.program.scoping.OperationUserDataHelper;
import org.eclipse.xtext.diagnostics.Severity;
import org.eclipse.xtext.resource.IEObjectDescription;
import org.eclipse.xtext.xbase.lib.IteratorExtensions;

import com.google.inject.Inject;

public class OperationsLinker {

	protected class PolymorphicComparator implements Comparator<IEObjectDescription> {

		public int compare(IEObjectDescription operation1, IEObjectDescription operation2) {
			List<Type> parameters1 = operationUserDataHelper.getParameterTypes(operation1);
			List<Type> parameters2 = operationUserDataHelper.getParameterTypes(operation2);

			if (parameters1.size() > parameters2.size()) {
				return -1;
			}
			if (parameters1.size() < parameters2.size()) {
				return 1;
			}

			for (int i = 0; i < parameters1.size(); i++) {
				final Type type1 = parameters1.get(i);
				final Type type2 = parameters2.get(i);

				if (typeSystem.isSame(type1, type2))
					continue;
				if (typeSystem.isSuperType(type1, type2)) {
					return 1;
				}
				if (typeSystem.isSuperType(type2, type1)) {
					return -1;
				}
			}
			return 0;
		}
	}

	@Inject
	protected ITypeSystemInferrer inferrer;
	@Inject
	protected TypeValidator validator;
	@Inject
	protected ITypeSystem typeSystem;
	@Inject
	protected ExtensionMethodHelper extensionMethodHelper;
	@Inject
	protected OperationUserDataHelper operationUserDataHelper;

	public Optional<Operation> linkOperation(List<IEObjectDescription> candidates, ArgumentExpression call) {
		if (candidates.size() == 1 && candidates.get(0).getEClass().isSuperTypeOf(TypesPackage.Literals.OPERATION)) {
			return Optional.of((Operation) candidates.get(0).getEObjectOrProxy());
		}

		Collections.sort(candidates, new PolymorphicComparator());
		for (IEObjectDescription operation : candidates) {
			if (isCallable(operation, call)) {
				return Optional.of((Operation) operation.getEObjectOrProxy());
			}
		}

		return Optional.empty();
	}

	protected List<InferenceResult> getArgumentTypes(Operation operation, ArgumentExpression expression) {
		List<Expression> orderedExpressions = ArgumentSorter.getOrderedExpressions(expression.getArguments(),
				operation);
//		if (expression instanceof FeatureCall) {
//			Expression owner = ((FeatureCall) expression).getOwner();
//			InferenceResult ownerType = inferrer.infer(owner);
//			if (extensionMethodHelper.isExtensionMethodOn(operation, ownerType.getType())) {
//				orderedExpressions = extensionMethodHelper.combine(((FeatureCall) expression).getOwner(),
//						orderedExpressions);
//			}
//
//		}
		return newArrayList(transform(orderedExpressions, (e) -> inferrer.infer(e)));
	}

	protected boolean isCallable(IEObjectDescription operation, ArgumentExpression expression) {
		Operation op = (Operation) operation.getEObjectOrProxy();

		if (!op.eIsProxy()) {
			return isCallableByType(operation, getArgumentTypes(op, expression));
		} else {
			return isCallableByName(operation, getArgumentTypes(op, expression));
		}

	}

	protected boolean isCallableByName(IEObjectDescription operation, List<InferenceResult> argumentTypes) {
		List<String> parameterTypes = Arrays.asList(operationUserDataHelper.getParameterTypeNames(operation));

		if (argumentTypes.size() != parameterTypes.size())
			return false;

		for (int i = 0; i < argumentTypes.size(); i++) {
			String parameterTypeName = parameterTypes.get(i);
			if (!isSubtype(argumentTypes.get(i).getType(), parameterTypeName)) {
				return false;
			}
		}
		return true;
	}

	protected boolean isSubtype(Type subType, String superTypeName) {
		if (subType.getName().equals(superTypeName)) {
			return true;
		}
		return IteratorExtensions.exists(typeSystem.getSuperTypes(subType).iterator(),
				(t) -> t.getName().equals(superTypeName));
	}

	protected boolean isCallableByType(IEObjectDescription operation, List<InferenceResult> argumentTypes) {
		List<InferenceResult> parameterTypes = operationUserDataHelper.getParameterInferenceResults(operation);

		if (argumentTypes.size() != parameterTypes.size())
			return false;

		for (int i = 0; i < argumentTypes.size(); i++) {
			InferenceResult argumentType = argumentTypes.get(i);
			InferenceResult parameterType = parameterTypes.get(i);
			IValidationIssueAcceptor.ListBasedValidationIssueAcceptor acceptor = new IValidationIssueAcceptor.ListBasedValidationIssueAcceptor();
			validator.assertAssignable(parameterType, argumentType,
					String.format("Types are incompatible", argumentType, parameterType), acceptor);
			if (!acceptor.getTraces(Severity.ERROR).isEmpty()) {
				return false;
			}
		}
		return true;
	}
}
