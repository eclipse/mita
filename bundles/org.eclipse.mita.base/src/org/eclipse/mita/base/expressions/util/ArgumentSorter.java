/**
 * Copyright (c) 2017 itemis AG and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * 
 * Contributors:
 * 	itemis AG - initial API and implementation
 * 
 */
package org.eclipse.mita.base.expressions.util;

import java.util.List;

import org.eclipse.emf.common.util.BasicEList;
import org.eclipse.emf.common.util.EList;
import org.eclipse.mita.base.expressions.Argument;
import org.eclipse.mita.base.expressions.Expression;
import org.eclipse.mita.base.types.Operation;
import org.eclipse.mita.base.types.Parameter;

/**
 * 
 * @author andreas muelder - Initial contribution and API
 * 
 */
public class ArgumentSorter {

	public static EList<Expression> getOrderedExpressions(List<Argument> arguments, Operation operation) {
		Expression[] result = new Expression[arguments.size()];
		for (int index = 0; index < arguments.size(); index++) {
			Argument argument = arguments.get(index);
			if (argument.getParameter() == null)
				result[index] = argument.getValue();
			else {
				// operation.getParameters().indexOf(argument.getParameter() can
				// not be used here since it uses object.equals instead of
				// EcoreUtil.equals.)
				for (Parameter param : operation.getParameters()) {
					if (param.getName().equals(argument.getParameter().getName())) {
						int parameterIndex = operation.getParameters().indexOf(param);
						if (parameterIndex < result.length)
							result[parameterIndex] = argument.getValue();
						break;
					}
				}
			}
		}

		EList<Expression> resultAsList = new BasicEList<Expression>();
		for (int i = 0; i < result.length; i++) {
			Expression expression = result[i];
			if (expression != null)
				resultAsList.add(expression);
		}
		return resultAsList;
	}
}