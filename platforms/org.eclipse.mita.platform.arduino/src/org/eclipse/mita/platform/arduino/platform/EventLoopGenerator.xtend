/********************************************************************************
 * Copyright (c) 2018 itemis AG.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    itemis AG - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.platform.arduino.platform

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
	
	def generateEventloopInject(String functionName, String userParam1, String userParam2) {
		return codeFragmentProvider.create('''
			«functionName»();
		''')
	}
	
	def generateEventloopInject(String functionName) {
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
			«IF context.allTimeEvents.length !== 0» 
				#define TIMED_APPLICATION
			«ENDIF»
			«FOR handler : context.allEventHandlers»
				
				volatile bool «handler.handlerName»_flag;
				bool get«handler.handlerName»_flag();
				void set«handler.handlerName»(bool val);
			«ENDFOR»
		''');
	}
	
	override generateEventLoopHandlerSignature(CompilationContext context) {
		return CodeFragment.EMPTY;
	}
	
	override generateEventLoopHandlerPreamble(CompilationContext context, EventHandlerDeclaration handler) {
		return CodeFragment.EMPTY
	}
	
	override generateSetupPreamble(CompilationContext context) {
		return CodeFragment.EMPTY;
	}
	
	override generateEnablePreamble(CompilationContext context) {
		return CodeFragment.EMPTY;
	}	
}
