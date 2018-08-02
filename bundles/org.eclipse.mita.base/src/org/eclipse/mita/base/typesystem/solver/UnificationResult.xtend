package org.eclipse.mita.base.typesystem.solver

import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor
@Accessors
class UnificationResult {
	protected final Substitution substitution;
	protected final UnificationIssue issue;
	
	override toString() {
		if(isValid) {
			substitution.toString();
		} else {
			issue.toString();
		}
	}
	
	def isValid() {
		return substitution !== null && issue === null;
	}
	
	static def UnificationResult success(Substitution substitution) {
		return new UnificationResult(substitution ?: Substitution.EMPTY, null);
	}
	
	static def UnificationResult failure(UnificationIssue issue) {
		return new UnificationResult(null, issue);
	}
	
	static def UnificationResult failure(Object origin, String issue) {
		return new UnificationResult(null, new UnificationIssue(origin, issue));
	}
	
}