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

import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IPlatformEventLoopGenerator
import org.eclipse.mita.program.generator.IPlatformExceptionGenerator
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.types.StructureType
import org.eclipse.mita.types.SumType
import com.google.inject.Inject
import org.eclipse.xtext.EcoreUtil2
import org.yakindu.base.expressions.expressions.ElementReferenceExpression
import org.yakindu.base.types.EnumerationType
import org.eclipse.mita.program.NativeFunctionDefinition

class UserCodeFileGenerator { 
	
	@Inject
	protected extension GeneratorUtils
	
	@Inject
	protected extension ProgramCopier
	
	@Inject(optional=true)
	protected IPlatformEventLoopGenerator eventLoopGenerator

	@Inject(optional=true)
	protected IPlatformExceptionGenerator exceptionGenerator

    @Inject
    protected CodeFragmentProvider codeFragmentProvider

    @Inject
	protected StatementGenerator statementGenerator

	/**
	 * Generates custom types used by the application.
	 */
	def generateHeader(CompilationContext context, Program program) {
		return codeFragmentProvider.create('''	
			«FOR function : program.functionDefinitions.filter(FunctionDefinition)»
			«statementGenerator.header(function)»
			«ENDFOR»
		''')
		.addHeader(program.getResourceTypesName + '.h', false)
		.toHeader(context, program.resourceBaseName.toUpperCase + '_H');
	}
	
	def generateTypes(CompilationContext context, Program program) {
		return codeFragmentProvider.create('''
		«FOR struct : program.types.filter(StructureType)»
		«statementGenerator.header(struct)»
		«ENDFOR»

		«FOR enumType : program.types.filter(EnumerationType)»
		«statementGenerator.header(enumType)»
		«ENDFOR»
		
		«FOR sumType : program.types.filter(SumType)»
		«statementGenerator.header(sumType)»
		«ENDFOR»
		''').toHeader(context, program.getResourceTypesName.toUpperCase + '_H');
	}

	def generateImplementation(CompilationContext context, Program program) {
		// Start code generation session
		return codeFragmentProvider.create('''
			«generateGlobalVariables(program)»
			
			«generateEventHandlers(context, program)»
			«generateFunctions(program)»
		''')
		.addHeader(program.resourceBaseName + '.h', false)
		.addHeader(getContextIncludes(context, program))
		.toImplementation(context);
	}
	
	def String getResourceBaseName(Program program) {
		val resource = program.origin.eResource;
		return resource.URI.segments.last.replace('.' + resource.URI.fileExtension, '');
	}
	
	def String getResourceTypesName(Program program) {
		getResourceBaseName(program) + 'Types';
	}
	
	protected def getContextIncludes(CompilationContext context, Program program) {
		val allrefs = program.eAllContents
			.filter(ElementReferenceExpression)
			.toList;
		
		val allprogs = allrefs
			.map[ EcoreUtil2.getContainerOfType(it.reference, Program) ]
			.toList;
			
		val allintprogs = allprogs
			.filter[p| p != program && context.allUnits.exists[pu| pu.origin == p ] ]
			.toList;
			
		allintprogs
			.map[ it.resourceBaseName + '.h' ]
			.toSet
			.map[ new IncludePath(it, false) ];
	}
	
	def generateGlobalVariables(Program program) {
		return codeFragmentProvider.create('''
		«FOR variable : program.globalVariables»
		«statementGenerator.code(variable)»
		«ENDFOR»
		''')
	}
	
	private def generateEventHandlers(CompilationContext context, Program program) {		
		val exceptionType = exceptionGenerator.exceptionType;
		return codeFragmentProvider.create('''
			«FOR handler : program.eventHandlers»
			«exceptionType» «handler.handlerName»(«eventLoopGenerator.generateEventLoopHandlerSignature(context)»)
			{
				
				«eventLoopGenerator.generateEventLoopHandlerPreamble(context, handler)»
			«statementGenerator.code(handler.block).noBraces» 

				return NO_EXCEPTION;
			}
			
			«ENDFOR»
		''')
		.addHeader('MitaExceptions.h', false);
	}

	private def generateFunctions(Program program) {
		return codeFragmentProvider.create('''
			«FOR function : program.functionDefinitions.filter(FunctionDefinition)»
			«statementGenerator.code(function)»
			
			«ENDFOR»
			«FOR function : program.functionDefinitions.filter(NativeFunctionDefinition)»
			«codeFragmentProvider.create('''''').addHeader(function.header, true, IncludePath.ULTRA_LOW_PRIORITY)»
			«ENDFOR»
		''')
	}
	
}
