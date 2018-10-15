/**
 * Copyright (c) 2014 committers of YAKINDU and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * Contributors:
 * 	committers of YAKINDU - initial API and implementation
 * 
 */
package org.eclipse.mita.base.expressions.inferrer;

/**
 * @author andreas muelder - Initial contribution and API
 * 
 */
public interface ExpressionsTypeInferrerMessages {

	public static final String LOGICAL_OPERATOR = "Logical operator '%s' may only be applied on boolean types, not on %s.";
	public static final String LOGICAL_OPERATORS = "Logical operator '%s' may only be applied on boolean types, not on %s and %s.";
	public static final String COMPARSION_OPERATOR = "Comparison operator '%s' may only be applied on compatible types, not on %s and %s.";
	public static final String BITWISE_OPERATOR = "Bitwise operator '%s' may only be applied on integer types, not on %s.";
	public static final String BITWISE_OPERATORS = "Bitwise operator '%s' may only be applied on integer types, not on %s and %s.";
	public static final String ASSIGNMENT_OPERATOR = "Assignment operator '%s' may only be applied on compatible types, not on %s and %s.";
	public static final String ARITHMETIC_OPERATOR = "Arithmetic operator '%s' may only be applied on numeric types, not on %s.";
	public static final String ARITHMETIC_OPERATORS = "Arithmetic operator '%s' may only be applied on numeric types, not on %s and %s.";
	public static final String POSTFIX_OPERATOR = "Postfix operator '%s' may only be applied on numeric types, not on %s.";
	public static final String COMMON_TYPE = "Could not determine a common type for %s and %s.";
	public static final String CONDITIONAL_BOOLEAN = "conditional expression must be of type boolean.";
	public static final String CAST_OPERATORS = "Cannot cast from %s to %s.";
	public static final String CAN_NOT_CONVERT = "%s cannot be converted to '%s'.";
	public static final String INCOMPATIBLE_TYPES = "Incompatible types %s and %s.";
	public static final String INFER_COMMON_TYPE = "Could not infer common type for type parameter %s from argument types %s.";
	public static final String INFER_TYPE_PARAMETER = "Could not infer type for type parameter %s.";
	public static final String INFER_RETURN_TYPE_PARAMETER = "Could not infer type for return type parameter %s, returning ANY instead.";

}
