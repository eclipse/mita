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

/**
 * Base types are types without type variables (e.g. atomic types or integers)
 */
abstract class AbstractBaseType extends AbstractType {
	
	static def unify(ConstraintSystem system, Iterable<AbstractType> instances) {
		if(instances.groupBy[it].size == 1) {
			return instances.head;
		}
		return system.newTypeVariable(null);
	}
	
	new(EObject origin, String name) {
		super(origin, name)
	}
		
	override toGraphviz() {
		return "";
	}
	
	override Tree<AbstractType> quote() {
		return new Tree(this);
	}
	
	override quoteLike(Tree<AbstractType> structure) {
		return quote();
	}
	
	override replaceProxies(ConstraintSystem system, (TypeVariableProxy) => Iterable<AbstractType> resolve) {
		return this;
	}
	
	override map((AbstractType)=>AbstractType f) {
		return f.apply(this);
	}
	
	override modifyNames((String) => String converter) {
		return this;
	}
	
	override unquote(Iterable<Tree<AbstractType>> children) {
		return this;
	}
	
}