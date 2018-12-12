/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.program.generator.internal

import org.eclipse.mita.program.TimeIntervalEvent
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IPlatformExceptionGenerator
import org.eclipse.mita.program.generator.IPlatformTimeGenerator
import com.google.inject.Inject

class TimeEventGenerator {
	
	@Inject
	protected extension GeneratorUtils
	
	@Inject(optional = true)
	protected IPlatformExceptionGenerator exceptionGenerator
	
	@Inject(optional = true)
	protected IPlatformTimeGenerator timeGenerator

    @Inject
    protected CodeFragmentProvider codeFragmentProvider

	def generateHeader(CompilationContext context) {
		val exceptionType = exceptionGenerator.exceptionType
		val allTimeEventHandler = context.allEventHandlers.filter[e | e.event instanceof TimeIntervalEvent ];
		
		return codeFragmentProvider.create('''
			«exceptionType» SetupTime(void);

			«exceptionType» EnableTime(void);
			
			«FOR handler : allTimeEventHandler»
			«exceptionType» «handler.enableName»(void);
			«ENDFOR»
		''')
		.toHeader(context, 'MITA_TIME_H')
	}


	
	def generateImplementation(CompilationContext context) {
		val exceptionGenerator = exceptionGenerator;
		val generator = timeGenerator;
		
		// start code generation session
		val exceptionType = exceptionGenerator.exceptionType;
		
		// find all time event handler
		val allTimeEventHandler = context.allEventHandlers.filter[e | e.event instanceof TimeIntervalEvent ];		
				
		return codeFragmentProvider.create('''
			«exceptionType» SetupTime(void)
			{
				«generator.generateTimeSetup(context)»
				
				return NO_EXCEPTION;
			}
			
			«exceptionType» EnableTime(void)
			{
				«exceptionType» result = NO_EXCEPTION;
			
				«generator.generateTimeGoLive(context)»
				«FOR event : allTimeEventHandler»
				
				result = «event.enableName»();
				if(result != NO_EXCEPTION)
				{
					return result;
				}
				«ENDFOR»
				
				return NO_EXCEPTION;
			}
			
			«FOR event : allTimeEventHandler»
			«exceptionType» «event.enableName»(void)
			{
				«generator.generateTimeEnable(context, event)»
				
				return NO_EXCEPTION;
			}
			
			«ENDFOR»
		''')
		.addHeader('MitaTime.h', false)
		.toImplementation(context)
	}
	
}