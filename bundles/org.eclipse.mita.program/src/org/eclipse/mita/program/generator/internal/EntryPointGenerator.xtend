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

import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IPlatformEventLoopGenerator
import org.eclipse.mita.program.generator.IPlatformExceptionGenerator
import org.eclipse.mita.program.generator.IPlatformStartupGenerator
import com.google.inject.Inject
import java.util.LinkedList
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator

/**
 * Generates the main.c file of a Mita application.
 */
class EntryPointGenerator {
	
	@Inject
	protected extension GeneratorUtils 
	
	@Inject(optional = true)
	protected IPlatformStartupGenerator startupGenerator
	
	@Inject(optional = true)
	protected IPlatformExceptionGenerator exceptionGenerator
	
	@Inject(optional = true)
	protected IPlatformEventLoopGenerator eventLoopGenerator
	
	@Inject(optional = true)
	protected IPlatformLoggingGenerator loggingGenerator
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject
	protected UserCodeFileGenerator userCodeGenerator
	
	/**
	 * Generates the main.c file
	 */
	def generateMain(CompilationContext context) {
		// get the generators we need
		val exceptionType = exceptionGenerator.exceptionType;
		
		
		// find all resources used
		val allResourcesUsed = context.resourceGraph
			.nodesInTopolicalOrder
			.filter[ it instanceof AbstractSystemResource || it instanceof SystemResourceSetup ]
			.filter(EObject)
			.toList;
		
		// build list of base includes
		val baseIncludes = new LinkedList();
		baseIncludes.add(new IncludePath('MitaExceptions.h', false));
		baseIncludes.add(new IncludePath('MitaEvents.h', false));
		if(context.hasTimeEvents) {
			baseIncludes.add(new IncludePath('MitaTime.h', false));
		}
		for(systemResource : allResourcesUsed) {
			baseIncludes.add(new IncludePath(systemResource.fileBasename + '.h', false));
		}
		for(program : context.allUnits.filter[containsCodeRelevantContent]) {
			baseIncludes.add(new IncludePath(userCodeGenerator.getResourceBaseName(program) + '.h', false))
		}
		
		// and produce code
		codeFragmentProvider.create('''
			int main(void)
			{
				«startupGenerator.generateMain(context)»
			}
			
			«exceptionType» Mita_initialize(«eventLoopGenerator.generateEventLoopHandlerSignature(context)»)
			{
				«eventLoopGenerator.generateEventLoopHandlerPreamble(context, null)»
				«exceptionType» exception = NO_EXCEPTION;
				
				«eventLoopGenerator.generateSetupPreamble(context)»

				«IF context.hasTimeEvents»

				// setup time
				exception = SetupTime();
				«"Time".generateLoggingExceptionHandler("setup")»
				«ENDIF»
			
				«IF !allResourcesUsed.empty»
				// setup resources
				«FOR resource : allResourcesUsed»
				exception = «resource.setupName»();
				«resource.baseName.generateLoggingExceptionHandler("setup")»
				
				«ENDFOR»
				«ENDIF»
				return exception;
			}
			
			«exceptionType» Mita_goLive(«eventLoopGenerator.generateEventLoopHandlerSignature(context)»)
			{
				«eventLoopGenerator.generateEventLoopHandlerPreamble(context, null)»
				«exceptionType» exception = NO_EXCEPTION;
				
				«eventLoopGenerator.generateEnablePreamble(context)»

				«IF context.hasTimeEvents»
				exception = EnableTime();
				«"Time".generateLoggingExceptionHandler("enable")»
				
				«ENDIF»
				«FOR resource : allResourcesUsed»
				exception = «resource.enableName»();
				«resource.baseName.generateLoggingExceptionHandler("enable")»
				«ENDFOR»
				«FOR program: context.allUnits»
				«IF !program.globalVariables.empty»
				exception = «program.globalInitName»();
				«program.globalInitName.generateLoggingExceptionHandler("do")»
				«ENDIF»
				«ENDFOR»
				return NO_EXCEPTION;
			}
		''')
		.setPreamble('''
			static «exceptionType» Mita_initialize(«eventLoopGenerator.generateEventLoopHandlerSignature(context)»);
			static «exceptionType» Mita_goLive(«eventLoopGenerator.generateEventLoopHandlerSignature(context)»);
		''')
		.addHeader(baseIncludes)
		.toImplementation(context);
	}
	
	def generateEventHeader(CompilationContext context) {
		// produce code fragments
		val handlerSignature = eventLoopGenerator.generateEventLoopHandlerSignature(context);
		val exceptionType = exceptionGenerator.exceptionType;
		
		// produce header
		return codeFragmentProvider.create('''
			«eventLoopGenerator.generateEventHeaderPreamble(context)»
			
			«FOR handler : context.allEventHandlers»
			«exceptionType» «handler.handlerName»(«handlerSignature»);
			
			«ENDFOR»
		''')
		.toHeader(context, 'Mita_EVENTS_H');
	}
	
	
	
}
