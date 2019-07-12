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

import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.Variance
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.Tree
import org.eclipse.mita.base.typesystem.infra.TypeClassUnifier
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.xtend.lib.annotations.Accessors

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip
import org.eclipse.mita.base.types.ComplexType
import org.eclipse.mita.base.typesystem.BaseConstraintFactory

@Accessors
class TypeConstructorType extends AbstractType {
	protected static Integer instanceCount = 0;
	protected val List<Pair<AbstractType, Variance>> typeArgumentsAndVariances;
	private transient val List<TypeVariable> _freeVars;
	
	static def unify(ConstraintSystem system, Iterable<AbstractType> instances) {
		// if not all sum types have the same number of arguments, return a new TV
		if(instances.map[it as TypeConstructorType].map[it.typeArguments.size].groupBy[it].size > 1) {
			return system.newTypeVariable(null);
		}
		// else transpose the instances' type args (so we have a list of all the first args, all the second args, etc.), then unify each of those
		val typeArgs = BaseUtils.transpose(instances.map[it as TypeConstructorType].map[it.typeArguments])
				.map[TypeClassUnifier.INSTANCE.unifyTypeClassInstancesStructure(system, it)]
				.force;
		val name = typeArgs.head.name;
		return new TypeConstructorType(null, name, typeArgs.map[it -> Variance.UNKNOWN]);
	}
	
	override getName() {
		super.getName() ?: typeArguments.head.name
	}
	
	// the first argument is an atomic type referencing the type definition itself (or null), for example:
	// array<int32, 10> -> first argument is new AtomicType(\T, S. array<T, S>, "array")	
	new(EObject origin, String name, Iterable<Pair<AbstractType, Variance>> typeArgumentsAndVariances) {
		super(origin, name);
		
		this.typeArgumentsAndVariances = typeArgumentsAndVariances.force;
		if(this.typeArguments.contains(null)) {
			throw new NullPointerException;
		}
		this._freeVars = getTypeArguments().flatMap[it.freeVars].force;
		if(this.toString == "int32") {
			print("")
		}
	}
	
	new(EObject origin, AbstractType type, List<Pair<AbstractType, Variance>> typeArguments) {
		this(origin, type.name, #[type -> Variance.INVARIANT] + typeArguments);
	}
	
	new(EObject origin, AbstractType type, Iterable<Pair<AbstractType, Variance>> typeArguments) {
		this(origin, type.name, #[type -> Variance.INVARIANT] + typeArguments);
	}
		
	def getTypeArguments() {
		return typeArgumentsAndVariances.map[it.key]
	}	
	
	/* if you override this you don't need to implement:
	 * - map
	 * - replaceProxies
	 * - unquote
	 * - expand
	 */
	protected def TypeConstructorType constructor(EObject origin, String name, Iterable<Pair<AbstractType, Variance>> typeArgumentsAndVariances) {
		return new TypeConstructorType(origin, name, typeArgumentsAndVariances);
	}
		
	override Tree<AbstractType> quote() {
		val result = new Tree<AbstractType>(this);
		result.children += typeArguments.map[it.quote()];
		return result;
	}
	
	override quoteLike(Tree<AbstractType> structure) {
		val result = new Tree<AbstractType>(this);
		result.children += typeArguments.zip(structure.children).map[it.key.quoteLike(it.value)]
		return result;
	}
		
	def Variance getVariance(TypeConstructorType other, int typeArgumentIdx) {
		val selfResult = typeArgumentsAndVariances.get(typeArgumentIdx)?.value ?: Variance.UNKNOWN;
		if(selfResult != Variance.UNKNOWN) {
			return selfResult;
		}
		return other.typeArgumentsAndVariances.get(typeArgumentIdx)?.value ?: Variance.UNKNOWN;
	}
	
	def void expand(ConstraintSystem system, Substitution s, TypeVariable tv) {
		val newTypeVars = typeArguments.map[ system.newTypeVariable(it.origin) as AbstractType ].force;
		val newCType = this.constructor(origin, name, newTypeVars.zip(typeArgumentsAndVariances.map[it.value]));
		s.add(tv, newCType);
	}
		
	override toString() {
		return '''«super.toString»«IF !typeArguments.tail.empty»<«typeArguments.tail.join(", ")»>«ENDIF»'''
	}
	
	override getFreeVars() {
		return _freeVars;
	}
	
	override hasNoFreeVars() {
		return _freeVars.size === 0;
	}
	
	override toGraphviz() {
		'''«FOR t: typeArguments»"«t»" -> "«this»"; "«this»" -> "«t»" «t.toGraphviz»«ENDFOR»''';
	}
		
	override map((AbstractType)=>AbstractType f) {
		val newTypeArgs = typeArguments.map[ it.map(f) ].force;
		if(typeArguments.zip(newTypeArgs).exists[it.key !== it.value]) {
			return this.constructor(origin, name, newTypeArgs.zip(typeArgumentsAndVariances.map[it.value]));
		}
		return this;
	}
	
	override replaceProxies(ConstraintSystem system, (TypeVariableProxy)=>Iterable<AbstractType> resolve) {
		val result = super.replaceProxies(system, resolve);
		// if we successfully resolved a type with parameters, get its variances
		if(result instanceof TypeConstructorType) {
			val variancesStr = system.getUserData(this, BaseConstraintFactory.VARIANCES_KEY)
			if(variancesStr !== null) {
				// split at every character
				val variances = variancesStr.split("").map[
					Variance.get(it);
				]
				if(variances.length == result.typeArguments.tail.length) {
					val resultWithVariances = result.constructor(origin, result.name, result.typeArguments.zip(
						#[Variance.INVARIANT] + variances
					));
					return resultWithVariances;
				}
			}
		}
		return result;
	}
	
	override unquote(Iterable<Tree<AbstractType>> children) {
		return this.constructor(origin, name, children.map[it.node.unquote(it.children)].zip(typeArgumentsAndVariances.map[it.value]).force);
	}
	
	override boolean equals(Object obj) {
		if(this === obj) { 
			return true	
		}
		if(obj === null) {
			return false
		}
		if(getClass() !== obj.getClass()) {
			return false
		}
		if(!super.equals(obj)) {
			return false
		}
		var TypeConstructorType other = (obj as TypeConstructorType)
		if (this.typeArguments === null) {
			if(other.typeArguments !== null) {
				return false
			}
		} else if(this.typeArguments.size != (other.typeArguments.size)) {
			return false
		}
		else if(this.typeArguments.zip(other.typeArguments).exists[!it.key.equals(it.value)]) {
			return false;
		}
		return true
	}

	@Pure override int hashCode() {
		val int prime = 31
		var int result = super.hashCode()
		result = prime * result + (if((this.typeArguments === null)) 0 else this.typeArguments.hashCode() )
		return result
	}
}