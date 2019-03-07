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

package org.eclipse.mita.base.typesystem.solver

import java.util.List
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor
@Accessors
class ConstraintSolution {
	protected final ConstraintSystem constraintSystem;
	protected final Substitution solution;
	protected final List<ValidationIssue> issues;
	
	override toString() {
		'''
		Constraints:
			«constraintSystem»
		Issues:
			«FOR issue : issues SEPARATOR "\n"»«issue»«ENDFOR»
		Solution:
			«solution»
		'''
	}
	
}