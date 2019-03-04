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

import org.eclipse.mita.program.generator.IPlatformTimeGenerator
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import com.google.inject.Inject
import org.eclipse.mita.program.TimeIntervalEvent
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.generator.IPlatformEventLoopGenerator
import org.eclipse.mita.program.generator.GeneratorUtils

class TimeGenerator implements IPlatformTimeGenerator {

	@Inject
	protected extension CodeFragmentProvider codeFragmentProvider

	@Inject
	protected IPlatformEventLoopGenerator eventLoopGenerator

	@Inject
	protected extension GeneratorUtils
	
	override generateTimeEnable(CompilationContext context, EventHandlerDeclaration handler) {
		return codeFragmentProvider.create('''Timer_Enable();''')
	}

	override generateTimeGoLive(CompilationContext context) {
		return CodeFragment.EMPTY
	}

	override generateTimeSetup(CompilationContext context) {
		
		val body = codeFragmentProvider.create('''
			Exception_T result = STATUS_OK;
			
			result = Timer_Connect();
			if(result != STATUS_OK)
			{
				return result;
			}
		''')

		return codeFragmentProvider.create(body).setPreamble('''
			«FOR handler : context.allTimeEvents»
				«val period = ModelUtils.getIntervalInMilliseconds(handler.event as TimeIntervalEvent)»
				static uint32_t count_«period» = 0;
				bool get«handler.handlerName»_flag(){
					return «handler.handlerName»_flag;
				}
				
				void set«handler.handlerName»_flag(bool val){
					«handler.handlerName»_flag = val;
				}
			«ENDFOR»
			
			
			Exception_T Tick_Timer(void)
			{
			«FOR handler : context.allTimeEvents»
				«val period = ModelUtils.getIntervalInMilliseconds(handler.event as TimeIntervalEvent)»
					count_«period»++;
					if(count_«period» % «period» == 0)
					{
						count_«period» = 0;
						«handler.handlerName»_flag = true;
					}
				
			«ENDFOR»			
				return STATUS_OK;
			}
		''')
		.addHeader('MitaExceptions.h', false)
		.addHeader('MitaEvents.h', false)
		.addHeader('MitaTime.h', false)
		.addHeader('Timer.h', false)
	}
	
	override generateAdditionalHeaderContent(CompilationContext context) {
		return CodeFragment.EMPTY;
	}
	
}
