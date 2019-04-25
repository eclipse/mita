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
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

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
	
	/* Either<LEFT, RIGHT> is the opposite of a Pair<A, B>. Let's compare them:
	 * val Pair<Integer, Boolean> pair = new Pair<>(1, true);
	 * val Either<Integer, Boolean> intLeft = new Left<>(1);
	 * val Either<Integer, Boolean> boolRight = new Right<>(true);
	 * 
	 * now pair holds both 1 and true, where values of type Either<> hold only one of them.
	 * therefore one can look at pair as a much safer version of "Object", 
	 * since there are only two possible values that it may be instead of all classes on the classpath.
	 * 
	 * If this class is used more extensively we should add more functions like 
	 * - isLeft/isRight, 
	 * - map(Either<A,B>, A=>C, B=>D), 
	 * - match(onLeft: A=>C, onRight: B=>C), and so on. 
	 * For now instanceof is enough, since we use this only in TypeVariable.modifyNames.
	 */
	public static abstract class Either<LEFT, RIGHT> {
		public static def <LEFT, RIGHT> Either<LEFT, RIGHT> left(LEFT l) {
			return new Left(l);
		}
		public static def <LEFT, RIGHT> Either<LEFT, RIGHT> right(RIGHT r) {
			return new Right(r);
		}
	}
	@FinalFieldsConstructor
	public static class Left<T, R> extends Either<T, R> {
		public val T value;
	}
	@FinalFieldsConstructor
	public static class Right<T, R> extends Either<T, R> {
		public val R value;
	}
	// basically a typedef of (A ~ typeof(TypeVariable.uniqueId)) => A -> A
	public static abstract class NameModifier implements IntFunction<Either<Integer, String>> {
	}
	
}