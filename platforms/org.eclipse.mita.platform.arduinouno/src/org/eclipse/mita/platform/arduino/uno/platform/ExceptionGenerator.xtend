package org.eclipse.mita.platform.arduino.uno.platform

import com.google.inject.Inject
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.IPlatformExceptionGenerator
import org.eclipse.mita.base.types.Type

class ExceptionGenerator implements IPlatformExceptionGenerator {

	@Inject
	protected CodeFragmentProvider codeFragmentProvider

	override generateExceptionCodeFor(CompilationContext context, Type exception) {
		return CodeFragment.EMPTY
	}

	override generateRaiseException(CompilationContext context, String exceptionVariableName) {
		return CodeFragment.EMPTY
	}

	override getExceptionType() {
		return codeFragmentProvider.create('''Retcode_T''').addHeader("ARD_Retcode.h", false);
	}

	override getNoExceptionStatement() {
		return codeFragmentProvider.create('''RETCODE_OK''').addHeader("ARD_Retcode.h", false);
	}
	
}
