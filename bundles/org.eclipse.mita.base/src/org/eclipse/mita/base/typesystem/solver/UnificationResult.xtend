package org.eclipse.mita.base.typesystem.solver

import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor
@Accessors
class UnificationResult {
	protected final Substitution substition;
	protected final UnificationIssue issue;
	
	override toString() {
		if(isValid) {
			substition.toString();
		} else {
			issue.toString();
		}
	}
	
	def isValid() {
		return substition !== null && issue === null;
	}
	
	static def UnificationResult success(Substitution substitution) {
		return new UnificationResult(substitution ?: Substitution.EMPTY, null);
	}
	
	static def UnificationResult failure(UnificationIssue issue) {
		return new UnificationResult(null, issue);
	}
	
	static def UnificationResult failure(String issue) {
		return new UnificationResult(null, new UnificationIssue(issue));
	}
	
}