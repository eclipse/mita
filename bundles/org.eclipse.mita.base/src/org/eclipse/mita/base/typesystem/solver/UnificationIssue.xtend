package org.eclipse.mita.base.typesystem.solver

import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor
class UnificationIssue {
	protected final String message;
	
	override toString() {
		return '''UnificationIssue: «message»''';
	}
	
}