package org.eclipse.mita.base.typesystem.solver

import org.eclipse.xtend.lib.annotations.Accessors
import java.util.List

@Accessors
class UnificationResult { 
	protected final Substitution substitution;
	protected final List<UnificationIssue> issues = newArrayList;
	
	new(Substitution sub, Iterable<? extends UnificationIssue> issues) {
		this.substitution = sub;
		this.issues += issues;
	}
	new(Substitution sub, UnificationIssue issue) {
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
	
	static def UnificationResult failure(UnificationIssue issue) {
		return new UnificationResult(null, issue);
	}
	
	static def UnificationResult failure(Object origin, String issue) {
		return new UnificationResult(null, new UnificationIssue(origin, issue));
	}
	static def UnificationResult failure(Object origin, Iterable<String> issues) {
		return new UnificationResult(null, issues.map[new UnificationIssue(origin, it)]);
	}
	
}