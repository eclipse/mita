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

package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@EqualsHashCode
@Accessors
class BaseKind extends AbstractBaseType {
	
	val AbstractType kindOf;
	
	new(EObject origin, String name, AbstractType kindOf) {
		super(origin, name);
		this.kindOf = kindOf;
	}
	
	override map((AbstractType)=>AbstractType f) {
		val newKindOf = kindOf.map(f);
		if(newKindOf !== kindOf) {
			return new BaseKind(origin, name, newKindOf);
		}
		return this;
	}
	override replaceProxies(ConstraintSystem system, (TypeVariableProxy) => Iterable<AbstractType> resolve) {
		return new BaseKind(origin, name, kindOf.replaceProxies(system, resolve));
	}
	
	override modifyNames(NameModifier converter) {
		return new BaseKind(origin, name, kindOf.modifyNames(converter));
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return new BaseKind(origin, name, kindOf.replace(from, with));
	}
	
	override replace(Substitution sub) {
		return new BaseKind(origin, name, kindOf.replace(sub));
	}
	
	override getFreeVars() {
		return kindOf.freeVars;
	}
	
	override toString() {
		return '''∗«IF kindOf instanceof TypeVariable»«name»«ELSE»«kindOf»«ENDIF»'''
	}
	
	override toGraphviz() {
		return toString;
	}
	
}