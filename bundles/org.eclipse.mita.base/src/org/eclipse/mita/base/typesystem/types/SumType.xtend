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
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.Tree
import org.eclipse.mita.base.typesystem.infra.TypeClassUnifier
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip

@EqualsHashCode
@Accessors
class SumType extends TypeConstructorType {
	
	static def unify(ConstraintSystem system, Iterable<AbstractType> instances) {
		// if not all sum types have the same number of arguments, return a new TV
		if(instances.map[it as SumType].map[it.typeArguments.size].groupBy[it].size > 1) {
			return system.newTypeVariable(null);
		}
		// else transpose the instances' type args (so we have a list of all the first args, all the second args, etc.), then unify each of those
		val typeArgs = BaseUtils.transpose(instances.map[it as TypeConstructorType].map[it.typeArguments])
				.map[TypeClassUnifier.INSTANCE.unifyTypeClassInstancesStructure(system, it)]
				.force;
		val name = typeArgs.head.name;
		return new SumType(null, name, typeArgs);
	}
	
	new(EObject origin, String name, Iterable<AbstractType> typeArguments) {
		super(origin, name, typeArguments)
	}
	new(EObject origin, AbstractType type, List<AbstractType> typeArguments) {
		super(origin, type, typeArguments);
	}
	new(EObject origin, AbstractType type, Iterable<AbstractType> typeArguments) {
		super(origin, type, typeArguments);
	}
			
	override toString() {
		(name ?: "") + "(" + typeArguments.tail.join(" | ") + ")"
	}
				
	override getVarianceForArgs(ValidationIssue issue, int typeArgumentIdx, AbstractType tau, AbstractType sigma) {
		return new SubtypeConstraint(tau, sigma, new ValidationIssue(issue, '''Incompatible types: %1$s is not subtype of %2$s.'''));
	}
	
	override expand(ConstraintSystem system, Substitution s, TypeVariable tv) {
		val newTypeVars = typeArguments.map[ system.newTypeVariable(it.origin) as AbstractType ].force;
		val newSType = new SumType(origin, name, newTypeVars);
		s.add(tv, newSType);
	}
	override toGraphviz() {
		'''«FOR t: typeArguments»"«t»" -> "«this»"; «t.toGraphviz»«ENDFOR»''';
	}
		
	override map((AbstractType)=>AbstractType f) {
		val newTypeArgs = typeArguments.map[ it.map(f) ].force;
		if(typeArguments.zip(newTypeArgs).exists[it.key !== it.value]) {
			return new SumType(origin, name, newTypeArgs);	
		}
		return this;
	}
	
	override unquote(Iterable<Tree<AbstractType>> children) {
		return new SumType(origin, name, children.map[it.node.unquote(it.children)].force);
	}
	
}