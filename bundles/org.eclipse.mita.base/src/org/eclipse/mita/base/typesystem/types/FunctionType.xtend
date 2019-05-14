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
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.Tree
import org.eclipse.mita.base.typesystem.infra.TypeClassUnifier
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip

@EqualsHashCode
@Accessors
class FunctionType extends TypeConstructorType {
	static def unify(ConstraintSystem system, Iterable<AbstractType> instances) {
		return new FunctionType(null, 
			TypeClassUnifier.INSTANCE.unifyTypeClassInstancesStructure(system, instances.map[it as TypeConstructorType].map[it.typeArguments.head]),
			TypeClassUnifier.INSTANCE.unifyTypeClassInstancesStructure(system, instances.map[it as FunctionType].map[it.from]),
			TypeClassUnifier.INSTANCE.unifyTypeClassInstancesStructure(system, instances.map[it as FunctionType].map[it.to])
		)
	}
			
	new(EObject origin, AbstractType type, AbstractType from, AbstractType to) {
		this(origin, type.name, #[type, from, to]);
	}
	
	new(EObject origin, String name, Iterable<AbstractType> typeArgs) {
		super(origin, name, typeArgs);
	}
	
	def AbstractType getFrom() {
		return typeArguments.get(1);
	}
	def AbstractType getTo() {
		return typeArguments.get(2);
	}
	
	override toString() {
		from + " → " + to
	}
		
	override getVarianceForArgs(ValidationIssue issue, int typeArgumentIdx, AbstractType tau, AbstractType sigma) {
		if(typeArgumentIdx == 2) {
			return new SubtypeConstraint(tau, sigma, new ValidationIssue(issue, '''Incompatible types: %1$s is not subtype of %2$s.'''));
		}
		else {
			// function arguments are contravariant
			return new SubtypeConstraint(sigma, tau, new ValidationIssue(issue, '''Incompatible types: %1$s is not subtype of %2$s.'''));
		}
	}
	
	override expand(ConstraintSystem system, Substitution s, TypeVariable tv) {
		val newFType = new FunctionType(origin, typeArguments.head, system.newTypeVariable(from.origin), system.newTypeVariable(to.origin));
		s.add(tv, newFType);
	}
	
	override toGraphviz() {
		'''"«to»" -> "«this»"; "«this»" -> "«from»"; «to.toGraphviz» «from.toGraphviz»''';
	}
	

	override unquote(Iterable<Tree<AbstractType>> children) {
		return new FunctionType(origin, name, children.map[it.node.unquote(it.children)].force);
	}
	
	override map((AbstractType)=>AbstractType f) {
		val newTypeArgs = typeArguments.map[ it.map(f) ].force;
		if(typeArguments.zip(newTypeArgs).exists[it.key !== it.value]) {
			return new FunctionType(origin, name, newTypeArgs);
		}
		return this;
	}
	
}