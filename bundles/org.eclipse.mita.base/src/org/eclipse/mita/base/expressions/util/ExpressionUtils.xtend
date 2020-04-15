/********************************************************************************
 * Copyright (c) 2018, 2019 Robert Bosch GmbH & TypeFox GmbH
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH & TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.base.expressions.util

import java.util.TreeMap
import org.eclipse.mita.base.expressions.Argument
import org.eclipse.mita.base.expressions.ArgumentExpression
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.types.AnonymousProductType
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.NamedProductType
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.Parameter
import org.eclipse.mita.base.types.StructureType

import static extension org.eclipse.mita.base.util.BaseUtils.zip
import org.eclipse.mita.base.expressions.FeatureCallWithoutFeature

class ExpressionUtils {
	dispatch def static getArgumentsOfElementReferenceExpression(ArgumentExpression eref) {
		return eref.arguments
	}
	
	dispatch def static getArgumentsOfElementReferenceExpression(FeatureCallWithoutFeature eref) {
		return #[null] + eref.arguments
	}
	
	def static getSortedArgumentsAsMap(Iterable<? extends Parameter> parameters, Iterable<Argument> arguments) {
		val args = getSortedArguments(parameters, arguments);
		val map = new TreeMap<Parameter, Argument>([p1, p2 | p1.name.compareTo(p2.name)]);
		parameters.zip(args).forEach[map.put(it.key, it.value)];
		return map;
	}
	
	def static <P, A, P1 extends Parameter> Iterable<A> getSortedArguments(
		Iterable<P> parameters, Iterable<A> arguments, 
		(P) => P1 getParam, (A) => String getArgName, (P) => A getResultIfNotSupplied
	) {
		if(arguments.empty || getArgName.apply(arguments.head) === null) {
			arguments;
		}
		else {
			/* Important: we must not filterNull this list as that destroys the order of arguments. It is possible
			 * that we do not find an argument matching a parameter.
			 */
			parameters.map[parm | arguments.findFirst[getArgName.apply(it) == getParam.apply(parm).name] ?: getResultIfNotSupplied.apply(parm)]
		}
	}
	
	def static <T extends Parameter, A extends Argument> getSortedArguments(Iterable<T> parameters, Iterable<A> arguments) {
		return getSortedArguments(parameters, arguments, [it], [it.parameter?.name], [null]);
	}
	
	def static getFunctionCallArguments(ElementReferenceExpression functionCall) {
		if(functionCall === null || !functionCall.operationCall || functionCall.arguments.empty){
			return null;
		}
		
		val funRef = functionCall.reference;
		val arguments = functionCall.arguments;
		val typesAndArgsInOrder = if(funRef instanceof Operation) {
			zip(
				funRef.parameters.map[typeSpecifier],
				ExpressionUtils.getSortedArguments(funRef.parameters, arguments));
		} else if(funRef instanceof StructureType) {
			zip(
				funRef.parameters.map[typeSpecifier],
				ExpressionUtils.getSortedArguments(funRef.parameters, arguments));
		} else if(funRef instanceof NamedProductType) {
			zip(
				funRef.parameters.map[typeSpecifier],
				ExpressionUtils.getSortedArguments(funRef.parameters, arguments));
		} else if(funRef instanceof AnonymousProductType) {
			zip(
				funRef.typeSpecifiers,
				functionCall.arguments);
		} else {
			return null;
		}
		return typesAndArgsInOrder;
	}	
	
	/**
	 * Finds the value of an argument based on the name of its parameter.
	 */
	def static Expression getArgumentValue(Operation op, ArgumentExpression expr, String name) {
		// first check if we find a named argument
		val namedArg = expr.arguments.findFirst[x|x.parameter?.name == name];
		if(namedArg !== null) return namedArg.value;

		// we did not find a named arg. Let's look it up based on the index
		val sortedArgs = getSortedArguments(op.parameters, expr.arguments);
		
		var argIndex = op.parameters.indexed.findFirst[x|x.value.name == name]?.key
		// for extension methods the first arg is called "self"
		if(expr instanceof FeatureCall) {
			if(expr.operationCall) {
				if(name == "self") {
					return expr.arguments.head.value;
				}
			}
		}
		if(argIndex === null || argIndex >= sortedArgs.length) return null;

		return sortedArgs.get(argIndex)?.value;
	}
	
	def static Expression getArgumentValue(NamedProductType op, ArgumentExpression expr, String name) {
		// first check if we find a named argument
		val namedArg = expr.arguments.findFirst[x|x.parameter?.name == name];
		if(namedArg !== null) return namedArg.value;

		// we did not find a named arg. Let's look it up based on the index
		val sortedArgs = getSortedArguments(op.parameters, expr.arguments);
		
		var argIndex = op.parameters.indexed.findFirst[x|x.value.name == name]?.key
		// for extension methods the first arg is on the left side
		if(expr instanceof FeatureCall) {
			if(expr.operationCall) {
				if(argIndex == 0) {
					return expr.arguments.head.value;
				}
				argIndex--;	
			}
		}
		if(argIndex === null || argIndex >= sortedArgs.length) return null;

		return sortedArgs.get(argIndex)?.value;
	}
}