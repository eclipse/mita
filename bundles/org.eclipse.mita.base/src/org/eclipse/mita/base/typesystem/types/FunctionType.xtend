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
import org.eclipse.mita.base.types.Variance

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
		this(origin, type.name, #[type -> Variance.INVARIANT, from -> Variance.CONTRAVARIANT, to -> Variance.COVARIANT]);
	}
	
	new(EObject origin, String name, Iterable<Pair<AbstractType, Variance>> typeArgs) {
		super(origin, name, typeArgs);
	}
	
	override constructor(EObject origin, String name, Iterable<Pair<AbstractType, Variance>> typeArguments) {
		new FunctionType(origin, name, typeArguments);
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
		
	override toGraphviz() {
		'''"«to»" -> "«this»"; "«this»" -> "«from»"; «to.toGraphviz» «from.toGraphviz»''';
	}
	
}