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
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.diagnostics.Severity

@Accessors
class UnificationResult { 
	protected final Substitution substitution;
	protected final List<ValidationIssue> issues = newArrayList;
	
	new(Substitution sub, Iterable<ValidationIssue> issues) {
		this.substitution = sub;
		this.issues += issues;
	}
	new(Substitution sub, ValidationIssue issue) {
		this.substitution = sub;
		this.issues.add(issue);
		if(substitution === null && issue === null) {
			throw new NullPointerException();
		}
	}
	
	override toString() {
		if(isValid) {
			substitution.toString();
		} else {
			issues.join("\n");
		}
	}
	
	def isValid() {
		return substitution !== null && issues.nullOrEmpty;
	}
	
	static def UnificationResult success(Substitution substitution) {
		return new UnificationResult(substitution ?: Substitution.EMPTY, #[]);
	}
	
	static def UnificationResult failure(ValidationIssue issue) {
		return new UnificationResult(null, issue);
	}
	static def UnificationResult failure(Iterable<ValidationIssue> issues) {
		return new UnificationResult(null, issues);
	}
	
	static def UnificationResult failure(EObject origin, String issue) {
		return new UnificationResult(null, new ValidationIssue(Severity.ERROR, issue, origin, null, ""));
	}
	static def UnificationResult failure(EObject origin, Iterable<String> issues) {
		return new UnificationResult(null, issues.map[issue | new ValidationIssue(Severity.ERROR, issue, origin, null, "")]);
	}
	
}