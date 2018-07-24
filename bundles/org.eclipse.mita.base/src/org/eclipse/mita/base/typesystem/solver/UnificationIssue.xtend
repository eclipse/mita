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
	new(List<UnificationIssue> issues) {
		super(null, '''
		«FOR issue: issues SEPARATOR(' | ')»
			«issue.message»
		«ENDFOR»
		''')
		this.issues = issues;
	}
}