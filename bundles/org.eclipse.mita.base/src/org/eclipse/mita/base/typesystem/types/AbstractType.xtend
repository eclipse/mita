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

import java.util.function.IntFunction
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.infra.Tree
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.util.Either
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
abstract class AbstractType {
	
	static def AbstractType unify(ConstraintSystem system, Iterable<AbstractType> instances) {
		return system.newTypeVariable(null);
	} 
	
	protected transient EObject origin;
	protected final String name;
	
	abstract def AbstractType map((AbstractType) => AbstractType f);
	
	abstract def Tree<AbstractType> quote();
	abstract def Tree<AbstractType> quoteLike(Tree<AbstractType> structure);
	abstract def AbstractType unquote(Iterable<Tree<AbstractType>> children);
	
	protected new(EObject origin, String name) {
		this.origin = origin;
		this.name = name;
	}
		
	override boolean equals(Object other) {
		if (this === other)
		  return true;
		if (other === null)
		  return false;
		if (getClass() !== other.getClass())
		  return false;
		return name == (other as AbstractType).name;
	}
	
	override hashCode() {
		return name.hashCode();
	}
	
	def AbstractType replace(TypeVariable from, AbstractType with) {
		map[it.replace(from, with)];
	}
	
	def AbstractType replace(Substitution sub) {
		if(this.hasNoFreeVars) {
			return this;
		}
		return map[it.replace(sub)];
	}
	
	
	
	abstract def Iterable<TypeVariable> getFreeVars();
	
	def hasNoFreeVars() {
		return freeVars.empty;
	}
	
	override toString() {
		name
	}
	
	def generalize(ConstraintSystem system) {
		return new TypeScheme(origin, freeVars.toList, this);
	}
	
	abstract def String toGraphviz();
	
	def AbstractType replaceProxies(ConstraintSystem system, (TypeVariableProxy) => Iterable<AbstractType> resolve) {
		map[it.replaceProxies(system, resolve)];
	}
	
	def AbstractType modifyNames(NameModifier converter) {
		map[it.modifyNames(converter)];
	}

	// basically a typedef of (A ~ typeof(TypeVariable.uniqueId)) => A -> A
	public static abstract class NameModifier implements IntFunction<Either<Integer, String>> {
	}
	
	def boolean hasProxy() {
		return freeVars.exists[it instanceof TypeVariableProxy];
	}
	
}