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

import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.mita.base.typesystem.infra.NicerTypeVariableNamesForErrorMessages

@FinalFieldsConstructor
@Accessors
@EqualsHashCode
class JavaClassInstanceConstraint extends AbstractTypeConstraint {
	
	protected val AbstractType what;
	protected val Class<?> javaClass;
	
	override getErrorMessage() {
		val formatter = new NicerTypeVariableNamesForErrorMessages;
		val types = this.modifyNames(formatter) as JavaClassInstanceConstraint;
		return new ValidationIssue(_errorMessage, String.format(_errorMessage.message, types.what, types.javaClass.simpleName));
	}
	
	override getTypes() {
		return #[what];
	}
	
	override getMembers() {
		#[what, javaClass.simpleName]
	}
	
	override toGraphviz() {
		return what.toGraphviz;
	}
	
	override toString() {
		return '''«what» instanceof «javaClass.simpleName»''';
	}
	
	override map((AbstractType)=>AbstractType f) {
		val newWhat = f.apply(what);
		if(what !== newWhat) {
			return new JavaClassInstanceConstraint(_errorMessage, what.map(f), javaClass);
		}
		return this;
	}
	override getOperator() {
		return "java instanceof"
	}
	
	override isAtomic(ConstraintSystem system) {
		return what instanceof TypeVariable
	}
	
	override hasProxy() {
		return what.hasProxy
	}
	
}