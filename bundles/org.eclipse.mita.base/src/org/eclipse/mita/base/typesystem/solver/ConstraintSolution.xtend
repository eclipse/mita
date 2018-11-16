package org.eclipse.mita.base.typesystem.solver

import java.util.List
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor
@Accessors
class ConstraintSolution {
	protected final ConstraintSystem constraints;
	protected final Substitution solution;
	protected final List<ValidationIssue> issues;
	
	override toString() {
		'''
		Constraints:
			«constraints»
		Issues:
			«FOR issue : issues SEPARATOR "\n"»«issue»«ENDFOR»
		Solution:
			«solution»
		'''
	}
	
}