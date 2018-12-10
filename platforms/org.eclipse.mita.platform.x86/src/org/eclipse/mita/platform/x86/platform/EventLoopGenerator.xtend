/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *    itemis AG - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.platform.x86.platform

import com.google.inject.Inject
import org.eclipse.mita.platform.SystemResourceEvent
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.SystemEventSource
import org.eclipse.mita.program.TimeIntervalEvent
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IPlatformEventLoopGenerator
import org.eclipse.mita.program.model.ModelUtils

class EventLoopGenerator implements IPlatformEventLoopGenerator {

	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject 
	protected extension GeneratorUtils
	
	public def generateEventloopInject(String functionName, String userParam1, String userParam2) {
		return codeFragmentProvider.create('''
			«functionName»();
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
			«FOR handler : context.allEventHandlers.filter[it.event instanceof SystemEventSource]»
				volatile bool «handler.handlerName»_flag;
			«ENDFOR»
			«FOR handler : context.allTimeEvents»
				«val period = ModelUtils.getIntervalInMilliseconds(handler.event as TimeIntervalEvent)»
				clock_t lastTick«period.toString.toFirstUpper»;
			«ENDFOR»
		''')
		.addHeader("stdbool.h", true);
	}
	
	override generateEventLoopHandlerSignature(CompilationContext context) {
		return CodeFragment.EMPTY;
	}
	
	override generateEventLoopHandlerPreamble(CompilationContext context, EventHandlerDeclaration handler) {
		return CodeFragment.EMPTY
	}
	
	override generateSetupPreamble(CompilationContext context) {
		val startupEventHandler = context.allEventHandlers.filter[it.event instanceof SystemEventSource].findFirst[(it.event as SystemEventSource).source.name == "startup"]
		return codeFragmentProvider.create('''
			«IF startupEventHandler !== null»
			«startupEventHandler.handlerName»_flag = 1;
			«ENDIF»
		''');
	}
	
	override generateEnablePreamble(CompilationContext context) {
		return CodeFragment.EMPTY;
	}
	
}
