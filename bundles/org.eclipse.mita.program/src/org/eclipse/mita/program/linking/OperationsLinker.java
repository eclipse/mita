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

import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

import org.eclipse.xtext.resource.IEObjectDescription;
import org.yakindu.base.expressions.expressions.ArgumentExpression;
import org.yakindu.base.expressions.expressions.Expression;
import org.yakindu.base.expressions.expressions.FeatureCall;
import org.yakindu.base.expressions.expressions.util.ArgumentSorter;
import org.yakindu.base.types.Operation;
import org.yakindu.base.types.Type;
import org.yakindu.base.types.TypesPackage;
import org.yakindu.base.types.inferrer.ITypeSystemInferrer;
import org.yakindu.base.types.inferrer.ITypeSystemInferrer.InferenceResult;
import org.yakindu.base.types.typesystem.ITypeSystem;

import org.eclipse.mita.program.scoping.ExtensionMethodHelper;
import org.eclipse.mita.program.scoping.OperationUserDataHelper;
import com.google.inject.Inject;

public class OperationsLinker {

	protected class PolymorphicComparator implements Comparator<IEObjectDescription> {

		public int compare(IEObjectDescription operation1, IEObjectDescription operation2) {
			List<Type> parameters1 = operationUserDataHelper.getArgumentTypes(operation1);
			List<Type> parameters2 = operationUserDataHelper.getArgumentTypes(operation2);
			
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
	protected ITypeSystem typeSystem;
	@Inject
	protected ExtensionMethodHelper extensionMethodHelper;
	@Inject
	protected OperationUserDataHelper operationUserDataHelper;

	public Optional<Operation> linkOperation(List<IEObjectDescription> candidates, ArgumentExpression call) {
		if(candidates.size() == 1 && candidates.get(0).getEClass().isSuperTypeOf(TypesPackage.Literals.OPERATION)) {
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

	protected List<Type> getArgumentTypes(Operation operation, ArgumentExpression expression) {
		List<Expression> orderedExpressions = ArgumentSorter.getOrderedExpressions(expression.getArguments(), operation);
		if (expression instanceof FeatureCall) {
			Expression owner = ((FeatureCall) expression).getOwner();
			InferenceResult ownerType = inferrer.infer(owner);
			if (extensionMethodHelper.isExtensionMethodOn(operation, ownerType.getType())) {
				orderedExpressions = extensionMethodHelper.combine(((FeatureCall) expression).getOwner(),
						orderedExpressions);
			}

		}
		return newArrayList(transform(orderedExpressions, (e) -> inferrer.infer(e).getType()));
	}

	protected boolean isCallable(IEObjectDescription operation, ArgumentExpression expression) {
		List<Type> argumentTypes = getArgumentTypes((Operation) operation.getEObjectOrProxy(), expression);
		List<Type> parameterTypes = operationUserDataHelper.getArgumentTypes(operation);
		if (argumentTypes.size() != parameterTypes.size())
			return false;
		for (int i = 0; i < argumentTypes.size(); i++) {
			Type type1 = argumentTypes.get(i);
			Type type2 = parameterTypes.get(i);
			if (!typeSystem.isSuperType(type2, type1))
				return false;
		}
		return true;
	}
}
