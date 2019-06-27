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

package org.eclipse.mita.library.stdlib

import org.eclipse.mita.base.expressions.ArrayAccessExpression
import org.eclipse.mita.base.expressions.ValueRange
import org.eclipse.mita.base.types.Variance
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.MaxConstraint
import org.eclipse.mita.base.typesystem.constraints.SumConstraint
import org.eclipse.mita.base.typesystem.infra.InferenceContext
import org.eclipse.mita.base.typesystem.types.LiteralNumberType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.program.ArrayLiteral
import org.eclipse.mita.program.inferrer.StaticValueInferrer

import static org.eclipse.mita.program.inferrer.ProgramSizeInferrer.*

import static extension org.eclipse.mita.base.types.TypeUtils.ignoreCoercions
import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.types.AtomicType

class ArraySizeInferrer extends GenericContainerSizeInferrer {
		
	override getDataTypeIndexes() {
		return #[1];
	}
	
	override getSizeTypeIndexes() {
		return #[2];
	}
	
	static def wrapInArray(InferenceContext c, StdlibTypeRegistry typeRegistry, AbstractType t) {
		val arrayTypeObject = typeRegistry.getTypeModelObject(c.obj, StdlibTypeRegistry.arrayTypeQID);
		// \T S. array<T, S>
		val arrayType = c.system.getTypeVariable(arrayTypeObject);
		// t0 ~ array<t, s>
		val arrayInstance = c.system.newTypeVariable(c.obj);
		// t0 instanceof \T. sigInst<T> => creates t0 := sigInst<t1>
		c.system.addConstraint(new ExplicitInstanceConstraint(arrayInstance, arrayType, new ValidationIssue('''%s is not instance of %s''', c.obj)));
		// bind sigInst<t> to t0
		c.system.addConstraint(new EqualityConstraint(arrayInstance, new TypeConstructorType(c.obj, "array", #[new AtomicType(arrayTypeObject, "array") -> Variance.INVARIANT, t -> Variance.INVARIANT, c.system.newTypeVariable(null) -> Variance.COVARIANT]), new ValidationIssue('''%s is not instance of %s''', c.obj)))
		// return t0 ~ sigInst<t>
		return arrayInstance;
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, ArrayLiteral lit, TypeConstructorType t) {	
		val innerDataType = c.system.newTypeVariable(lit);
		val oldDataType = t.typeArguments.get(1)
		val u32 = typeRegistry.getTypeModelObject(lit, StdlibTypeRegistry.u32TypeQID);
		val u32Type = c.system.getTypeVariable(u32);
		c.system.addConstraint(new MaxConstraint(innerDataType, lit.values.map[
				c.system.getTypeVariable(it)
			] 
			// add the original type here to make for example [1,2,3]: array<uint32, _> (because of other use) type to *uint32* instead of xint8 
			+ #[oldDataType], new ValidationIssue('''''', lit)));
		
		c.system.associate(new TypeConstructorType(lit, t.name, #[
			t.typeArguments.head -> Variance.INVARIANT, 
			innerDataType -> Variance.INVARIANT, 
			new LiteralNumberType(lit, lit.values.length, u32Type) -> Variance.COVARIANT
		]), lit);
	}

	dispatch def void doCreateConstraints(InferenceContext c, ArrayAccessExpression expr, TypeConstructorType type) {
		val arraySelectorRange = expr.arraySelector.ignoreCoercions?.castOrNull(ValueRange);
		if(arraySelectorRange !== null) {
			val u32 = typeRegistry.getTypeModelObject(expr, StdlibTypeRegistry.u32TypeQID);
			val u32Type = c.system.getTypeVariable(u32);
			val ownerSize = typeVariableToTypeConstructorType(c, c.system.getTypeVariable(expr.owner), type).typeArguments.last;
			val lowerBound = new LiteralNumberType(arraySelectorRange.lowerBound, -1 * (StaticValueInferrer.infer(arraySelectorRange.lowerBound, [])?.castOrNull(Long) ?: 0L), u32Type);
			val upperBoundInferred = StaticValueInferrer.infer(arraySelectorRange.upperBound, [])?.castOrNull(Long);
			val upperBound = if(upperBoundInferred !== null) {
				new LiteralNumberType(arraySelectorRange.upperBound, upperBoundInferred, u32Type);
			}
			else {
				ownerSize	
			}
			val exprSizeType = typeVariableToTypeConstructorType(c, c.system.getTypeVariable(expr), type).typeArguments.last as TypeVariable;
			c.system.addConstraint(new SumConstraint(exprSizeType, #[upperBound, lowerBound], new ValidationIssue('''''', expr)));
		}
		else {
			wrapInArray(c, typeRegistry, type);
		}
		c.system.associate(type, expr);
	}
	
}