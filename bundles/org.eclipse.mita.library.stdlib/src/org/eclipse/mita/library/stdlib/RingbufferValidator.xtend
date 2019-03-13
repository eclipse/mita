package org.eclipse.mita.library.stdlib

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.xtext.validation.ValidationMessageAcceptor
import org.eclipse.mita.program.ProgramPackage

class RingbufferValidator implements IResourceValidator {
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		if(context instanceof VariableDeclaration) {
			if(context.eContainer instanceof Program) {
				if(context.const === false) {
					acceptor.acceptError("Global Ringbuffers must be constant", context, ProgramPackage.eINSTANCE.variableDeclaration_Writeable, 0, "");
				}
				if(context.initialization === null) {
					acceptor.acceptError("Global Ringbuffers must be initialized", context, null, 0, "");
				}
			}
		}
	}
	
}