package org.eclipse.mita.program.validation

import org.eclipse.mita.program.validation.ProgramDslValidator
import org.eclipse.emf.ecore.EDataType
import org.eclipse.emf.common.util.DiagnosticChain
import java.util.Map

class NullProgramDslValidator extends ProgramDslValidator {
	
	override validate(EDataType eDataType, Object value, DiagnosticChain diagnostics, Map<Object, Object> context) {
		return true
	}
	
}