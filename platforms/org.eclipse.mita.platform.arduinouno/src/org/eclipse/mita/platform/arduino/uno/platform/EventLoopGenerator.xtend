package org.eclipse.mita.platform.arduino.uno.platform

import com.google.inject.Inject
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IPlatformEventLoopGenerator

class EventLoopGenerator implements IPlatformEventLoopGenerator {

	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject 
	protected extension GeneratorUtils
	
	public def generateEventloopInject(String functionName, String userParam1, String userParam2) {
		return codeFragmentProvider.create('''
			�functionName�();
		''')
	}
	
	public def generateEventloopInject(String functionName) {
		return generateEventloopInject(functionName, '''NULL''', '''0''');
	}
	
	override generateEventLoopInject(CompilationContext context, String functionName) {
		return generateEventloopInject(functionName);
	}
	
	override generateEventLoopStart(CompilationContext context) {
		return CodeFragment.EMPTY;
	}
	
	override generateEventHeaderPreamble(CompilationContext context) {
		return codeFragmentProvider.create('''
			�IF context.allTimeEvents.length !== 0� 
			#define TIMED_APPLICATION
			�ENDIF�
			�FOR handler : context.allEventHandlers�
			
			bool �handler.handlerName�_flag;
			bool get�handler.handlerName�_flag();
			void set�handler.handlerName�(bool val);
			�ENDFOR�
		''');
	}
	
	override generateEventLoopHandlerSignature(CompilationContext context) {
		return codeFragmentProvider.create('''''');
	}
	
	override generateEventLoopHandlerPreamble(CompilationContext context, EventHandlerDeclaration handler) {
		return codeFragmentProvider.create('''
		''')
	}
}
