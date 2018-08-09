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

import java.util.HashMap
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.BoolLiteral
import org.eclipse.mita.base.expressions.DoubleLiteral
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.Expression
import org.eclipse.mita.base.expressions.FloatLiteral
import org.eclipse.mita.base.expressions.IntLiteral
import org.eclipse.mita.base.expressions.NumericalUnaryExpression
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.expressions.StringLiteral
import org.eclipse.mita.base.expressions.ValueRange
import org.eclipse.mita.base.types.AnonymousProductType
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.base.types.NamedProductType
import org.eclipse.mita.base.types.Parameter
import org.eclipse.mita.base.types.Singleton
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.SumType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.model.ModelUtils

import static extension org.eclipse.emf.common.util.ECollections.asEList
/**
 * Infers the value of an expression at compile time.
 */
class StaticValueInferrer {
	
	public static class SumTypeRepr {
				
		public val String name;
		public val Map<String, Expression> properties;
		public val SumType typ;
		public val SumAlternative constructor;
		public val Expression underlyingExpression;
		
		new(Map<String, Expression> p, SumAlternative c, Expression e) {
			name = c.name;
			properties = p;
			typ = c.eContainer as SumType;
			constructor = c;
			underlyingExpression = e;
		}
		
		override toString() {
			typ.name + "." + name + "(" + properties.entrySet.map[name_expr | name_expr.key + " = " StaticValueInferrer.infer(name_expr.value, [])].join(", ") + ")"
		}
		
	}
	static dispatch def Object infer(Singleton constr, ElementReferenceExpression expression, (EObject) => void inferenceBlockerAcceptor) {
		val props = new HashMap<String, Expression>(0);
		return new SumTypeRepr(props, constr, expression);	
	}
	static dispatch def Object infer(NamedProductType constr, ElementReferenceExpression expression, (EObject) => void inferenceBlockerAcceptor) {
		val propsRaw = ModelUtils.getSortedArgumentsAsMap(constr.parameters.map[it as Parameter].asEList, expression.arguments);
		val props = new HashMap<String, Expression>(propsRaw.size);
		propsRaw.forEach[p, a | props.put(p.name, a.value)]
		return new SumTypeRepr(props, constr, expression);
	}
	static dispatch def Object infer(AnonymousProductType constr, ElementReferenceExpression expression, (EObject) => void inferenceBlockerAcceptor) {
		val propsRaw = ModelUtils.getFunctionCallArguments(expression);
		val argc = propsRaw.size;
		val props = new HashMap<String, Expression>(argc);
		val idxs = 1..argc;
		BaseUtils.zip(idxs, propsRaw).forEach[idx__t_p | 
			val t_p = idx__t_p.value;
			props.put("_" + idx__t_p.key, t_p.value.value);
		]
		return new SumTypeRepr(props, constr, expression);
	}
	static dispatch def Object infer(EObject constr, ElementReferenceExpression expression, (EObject) => void inferenceBlockerAcceptor) {
		constr.infer(inferenceBlockerAcceptor);
	}
	
	
	
	static dispatch def Object infer(BoolLiteral expression, (EObject) => void inferenceBlockerAcceptor) {
		return expression.value;
	} 
	
	static dispatch def Object infer(DoubleLiteral expression, (EObject) => void inferenceBlockerAcceptor) {
		return expression.value;
	}
	
	static dispatch def Object infer(FloatLiteral expression, (EObject) => void inferenceBlockerAcceptor) {
		return expression.value;
	}
	
	static dispatch def Object infer(StringLiteral expression, (EObject) => void inferenceBlockerAcceptor) {
		return expression.value;
	}
	
	static dispatch def Object infer(IntLiteral expression, (EObject) => void inferenceBlockerAcceptor) {
		return expression.value;
	}
	
	static dispatch def Object infer(Enumerator expression, (EObject) => void inferenceBlockerAcceptor) {
		return expression;
	}
		
	static dispatch def Object infer(NumericalUnaryExpression expression, (EObject) => void inferenceBlockerAcceptor) {
		val inner = expression.operand.infer(inferenceBlockerAcceptor);
		if(inner === null || !(inner instanceof Integer || inner instanceof Float)) {
			return null;
		}
		val op = expression.operator;
		switch(op) {
			case NEGATIVE:
				if(inner instanceof Integer) {
					return (-1) * inner;	
				} else if(inner instanceof Float) {
					return (-1) * inner;	
				}
		}
		
		return null;
	}
	
	static dispatch def Object infer(PrimitiveValueExpression expression, (EObject) => void inferenceBlockerAcceptor) {
		return expression.value.infer(inferenceBlockerAcceptor);
	}
	
	static dispatch def Object infer(ElementReferenceExpression expression, (EObject) => void inferenceBlockerAcceptor) {
		val ref = expression.reference;
		if(ref !== null) {
			return infer(ref, expression, inferenceBlockerAcceptor);
		}
		inferenceBlockerAcceptor.apply(expression);
		return null;
	}
	
	static dispatch def Object infer(VariableDeclaration expression, (EObject) => void inferenceBlockerAcceptor) {
		if(expression.writeable) {
			inferenceBlockerAcceptor.apply(expression);
			return null;
		} else {
			return expression.initialization?.infer(inferenceBlockerAcceptor);
		}
	}
		
	static dispatch def Object infer(ValueRange expression, (EObject) => void inferenceBlockerAcceptor) {
		val lower = expression.lowerBound?.infer(inferenceBlockerAcceptor);
		if(expression.lowerBound !== null && lower === null) return null;
		val upper = expression.upperBound?.infer(inferenceBlockerAcceptor);
		if(expression.upperBound !== null && upper === null) return null;
		return #[lower, upper];
	}
	
	static dispatch def Object infer(Void expression, (EObject) => void inferenceBlockerAcceptor) {
		inferenceBlockerAcceptor.apply(null);
		return null;
	}
	
	static dispatch def Object infer(Expression expression, (EObject) => void inferenceBlockerAcceptor) {
		inferenceBlockerAcceptor.apply(expression);
		return null;
	}
	
	static dispatch def Object infer(EObject expression, (EObject) => void inferenceBlockerAcceptor) {
		inferenceBlockerAcceptor.apply(expression);
		return null;
	}
}