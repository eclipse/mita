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

package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.typesystem.types.TypeVariableProxy
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.mita.base.typesystem.types.AbstractType.NameModifier

@FinalFieldsConstructor
@EqualsHashCode
@Accessors
abstract class AbstractTypeConstraint {
	
	// You can use a format string as message to use final inferred types
	// java strings allow argument reuse with positional formatters like "%2$s" <-> second argument as string
	val ValidationIssue _errorMessage;
	def getErrorMessage() {
		return _errorMessage;	
	}
	
	abstract def AbstractTypeConstraint map((AbstractType) => AbstractType f);

	def AbstractTypeConstraint replace(TypeVariable from, AbstractType with) {
		return map[it.replace(from, with)];
	}

	def AbstractTypeConstraint replace(Substitution sub) {
		return map[it.replace(sub)];
	}
		
	/**
	 * @return all types involved in this constraint
	 */
	abstract def Iterable<AbstractType> getTypes();
	
	def String getOperator();
	
	def Iterable<Object> getMembers() {
		return getTypes().map[it];
	}
	
	abstract def String toGraphviz();
	
	abstract def boolean isAtomic(ConstraintSystem system);
	
	def AbstractTypeConstraint replaceProxies(ConstraintSystem system, (TypeVariableProxy) => Iterable<AbstractType> resolve) {
		var result = this;
		do {
			result = result.map[it.replaceProxies(system, resolve)]
		} while(result.hasProxy);
		return result;
	}
	
	def boolean hasProxy();
	
	def AbstractTypeConstraint modifyNames(NameModifier converter) {
		return map[it.modifyNames(converter)]
	}
}
