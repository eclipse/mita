package org.eclipse.mita.base.typesystem.solver

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