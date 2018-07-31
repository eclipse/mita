package org.eclipse.mita.base.typesystem.solver

import java.util.List
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor
@Accessors
class UnificationIssue {
	protected final Object origin;
	protected final String message;
	
	override toString() {
		return '''UnificationIssue: «message»''';
	}
	
}

class ComposedUnificationIssue extends UnificationIssue {
	protected final List<UnificationIssue> issues;
	protected new(List<UnificationIssue> issues) {
		super(null, 
		'''
		«FOR issue: issues»
		
			«issue»
		«ENDFOR»
		'''
		)
		this.issues = issues;
	}
	
	static def UnificationIssue fromMultiple(Iterable<UnificationIssue> issues) {
		val _issues = issues.filterNull.flatMap[
			if(it instanceof ComposedUnificationIssue) {
				it.issues
			}
			else {
				#[it]
			}
		].toList;
		if(_issues.size === 1) {
			return issues.head;	
		}
		else if(!_issues.empty) {
			return new ComposedUnificationIssue(_issues);
		}
		return null;
	}
}