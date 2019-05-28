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

import java.util.ArrayList
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.infra.Tree
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

import static extension org.eclipse.mita.base.util.BaseUtils.force
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.constraints.JavaClassInstanceConstraint

@EqualsHashCode
@Accessors
class TypeScheme extends AbstractType {	
	protected final List<TypeVariable> vars;
	protected final AbstractType on;
	
	new(EObject origin, List<TypeVariable> vars, AbstractType on) {
		super(origin, on.name);
		this.vars = vars;
		this.on = on;
	}
	
	override Tree<AbstractType> quote() {
		val result = new Tree<AbstractType>(this);
		result.children += on.quote();
		return result;
	}
	
	override quoteLike(Tree<AbstractType> structure) {
		val result = new Tree<AbstractType>(this);
		result.children += on.quoteLike(structure.children.head);
		return result;
	}
	
	override toString() {
		'''∀«vars».«on»'''
	}
	
	override replace(TypeVariable from, AbstractType with) {
		if(!vars.contains(from)) {			
			return new TypeScheme(origin, this.vars, this.on.replace(from, with));
		}
		else {
			return this;
		}
	}
	
	override getFreeVars() {
		return on.freeVars.filter(TypeVariable).reject[vars.contains(it)];
	}
	
	def instantiate(ConstraintSystem system) {
		val newVars = new ArrayList<TypeVariable>();
		val newOn = vars.fold(on, [term, boundVar | 
			val freeVar = system.newTypeVariable(null);
			if(boundVar instanceof DependentTypeVariable) {
				system.addConstraint(new SubtypeConstraint(freeVar, boundVar.dependsOn, new ValidationIssue("%s is not a %s", null)))
				system.addConstraint(new JavaClassInstanceConstraint(new ValidationIssue("%s is not instanceof %s", null), freeVar, LiteralTypeExpression));
			}
			newVars.add(freeVar);
			term.replace(boundVar, freeVar);
		]);
		
		return (newVars -> newOn);
	}
	
	override toGraphviz() {
		'''«FOR v: vars»"«v»" -> "«this»";«ENDFOR»'''
	}
	
	override replace(Substitution sub) {
		// slow path: collisions between bound vars and substitution. need to filter and apply manually.
		if(vars.exists[sub.content.containsKey(it.idx)]) {
			if(freeVars.forall[!sub.content.containsKey(it.idx)]) {
				// no need to do anything
				return this;
			}
			return new TypeScheme(origin, this.vars, 
				on.replace(sub.filter[vars.contains(it)])
			);
		} else {
			return new TypeScheme(origin, this.vars, this.on.replace(sub));			
		}
	}
		
	override map((AbstractType)=>AbstractType f) {
		return f.apply(this);
	}
	
	override replaceProxies(ConstraintSystem system, (TypeVariableProxy) => Iterable<AbstractType> resolve) {
		return new TypeScheme(origin, vars.map[replaceProxies(system, resolve) as TypeVariable].force, on.replaceProxies(system, resolve));
	}
	
	override modifyNames(NameModifier converter) {
		return new TypeScheme(origin, vars.map[modifyNames(converter) as TypeVariable].force, on.modifyNames(converter));
	}
	
	override unquote(Iterable<Tree<AbstractType>> children) {
		return new TypeScheme(origin, vars, children.head.node.unquote(children.head.children))
	}
	
}