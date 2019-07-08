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
import org.eclipse.mita.base.typesystem.infra.Tree
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.util.Left
import org.eclipse.mita.base.util.Right
import org.eclipse.xtend.lib.annotations.Accessors

/*
 * Info: TypeVariable.name is null unless an explicit display name is set.
 * toString is derived from idx, unless name is set.
 * This is used for nicer displaying of type variables.
 */
class TypeVariable extends AbstractType {
	@Accessors
	protected val int idx;
	
	static def unify(ConstraintSystem system, Iterable<AbstractType> instances) {
		return system.newTypeVariable(null);
	}
	
	new(EObject origin, int idx) {
		this(origin, idx, null);
	}
	
	new(EObject origin, int idx, String name) {
		super(origin, name);
		this.idx = idx;
	}
	
	def TypeVariable replaceOrigin(EObject origin) {
		return new TypeVariable(origin, idx, name);
	}
	
	override quote() {
		return new Tree(this);
	}
	
	override quoteLike(Tree<AbstractType> structure) {
		return quote();
	}
	
	override toString() {
		return (name ?: (toStringPrefix + idx));
	}
	override hashCode() {
		return idx.hashCode();
	}
	override boolean equals(Object other) {
		if (this === other)
		  return true;
		if (other === null)
		  return false;
		if (getClass() !== other.getClass())
		  return false;
		return idx == (other as TypeVariable).idx;
	}
	
	override getFreeVars() {
		return #[this];
	}
	
	override hasNoFreeVars() {
		return false;
	}
	
	override AbstractType replace(TypeVariable from, AbstractType with) {
		return if(from == this) {
			with;
		} 
		else {
			this;	
		}
	}
	
	override toGraphviz() {
		return '''"«this»"''';
	}
	
	override replace(Substitution sub) {
		sub.content.getOrDefault(this.idx, this)
	}
	
	override replaceProxies(ConstraintSystem system, (TypeVariableProxy) => Iterable<AbstractType> resolve) {
		return this;
	}
	
	override map((AbstractType)=>AbstractType f) {
		return f.apply(this);
	}

	override modifyNames(NameModifier converter) {
		val newName = converter.apply(idx);
		if(newName instanceof Left<?, ?>) {
			return new TypeVariable(origin, (newName as Left<Integer, String>).value, name);
		}
		else {
			return new TypeVariable(origin, idx, (newName as Right<Integer, String>).value);
		}
	}
	
	override unquote(Iterable<Tree<AbstractType>> children) {
		return this;
	}
	protected def getToStringPrefix() {
		return "f_";
	}
}

