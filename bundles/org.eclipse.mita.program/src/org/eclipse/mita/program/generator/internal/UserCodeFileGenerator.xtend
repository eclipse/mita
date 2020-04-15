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

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.types.EnumerationType
import org.eclipse.mita.base.types.PackageAssociation
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.SumType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.platform.SystemSpecification
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.NativeFunctionDefinition
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.generator.AbstractTypeGenerator
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IPlatformEventLoopGenerator
import org.eclipse.mita.program.generator.IPlatformExceptionGenerator
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.xtext.EcoreUtil2

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import static extension org.eclipse.mita.program.generator.internal.ProgramCopier.getOrigin

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
	
	@Inject
	protected GeneratorRegistry generatorRegistry
		
	/**
	 * Generates custom types used by the application.
	 */
	def generateHeader(CompilationContext context, Program program) {
		return codeFragmentProvider.create('''	
			«FOR function : program.functionDefinitions.filter(FunctionDefinition)»
			«statementGenerator.header(function)»
			«ENDFOR»
			«exceptionGenerator.exceptionType» «program.globalInitName»();
		''')
		.addHeader(program.getResourceTypesName + '.h', false)
		.toHeader(context, program.resourceBaseName.toUpperCase + '_H');
	}
	
	def generateTypes(CompilationContext context, Program program) {
		return generateTypes(context, program, program.types);
	}

	def generateTypes(CompilationContext context, SystemSpecification platform) {
		return generateTypes(context, platform, platform.types);
	}
	
	def generateTypes(CompilationContext context, PackageAssociation rootElement, Iterable<? extends EObject> types) {
		return codeFragmentProvider.create('''
		«FOR struct : types.filter(StructureType)»
		«statementGenerator.header(struct)»
		«ENDFOR»

		«FOR enumType : types.filter(EnumerationType)»
		«statementGenerator.header(enumType)»
		«ENDFOR»
		
		«FOR sumType : types.filter(SumType)»
		«statementGenerator.header(sumType)»
		«ENDFOR»
		''').toHeader(context, rootElement.getResourceTypesName.toUpperCase + '_H');
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
	
	static def String getResourceBaseName(PackageAssociation program) {
		val resource = program.origin.eResource;
		return resource.URI.segments.last.getResourceBaseName;
	}
	
	static def String getResourceBaseName(String programFileName) {
		// replace from last dot until end <-> remove file extension
		return programFileName.replaceFirst('\\.[^\\.]+$', '');
	}

	static def String getResourceTypesName(PackageAssociation program) {
		getResourceBaseName(program) + 'Types';
	}	
	
	static def String getResourceTypesName(String programFileName) {
		getResourceBaseName(programFileName) + 'Types';
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
		
		«exceptionGenerator.exceptionType» «program.globalInitName»() {
			«exceptionGenerator.exceptionType» exception = «exceptionGenerator.noExceptionStatement»;
			
			«FOR variable : program.globalVariables.filter[
				val type = BaseUtils.getType(it);
				return !ModelUtils.isStructuralType(type, it);
			]»
			«val type = BaseUtils.getType(variable)»
			«val generator = generatorRegistry.getGenerator(program.eResource, type)?.castOrNull(AbstractTypeGenerator)»
			«IF generator !== null»
			«generator.generateGlobalInitialization(type, variable, codeFragmentProvider.create('''«variable.name»'''), variable.initialization)»
			«ENDIF»
			«generateExceptionHandler(null, "exception")»
			
			«ENDFOR»
			return exception;
		}
		''')
	}
		
	
	
	
	private def generateEventHandlers(CompilationContext context, Program program) {		
		val exceptionType = exceptionGenerator.exceptionType;
		return codeFragmentProvider.create('''
			«FOR handler : program.eventHandlers»
				«exceptionType» «handler.handlerName»_worker()
				{
				«statementGenerator.code(handler.block).noBraces»
					return NO_EXCEPTION;
				}
				
				«exceptionType» «handler.handlerName»(«eventLoopGenerator.generateEventLoopHandlerSignature(context)»)
				{
					«exceptionType» exception = NO_EXCEPTION;
					«eventLoopGenerator.generateEventLoopHandlerPreamble(context, handler)»
					exception = «handler.handlerName»_worker();
					«eventLoopGenerator.generateEventLoopHandlerEpilogue(context, handler)»
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
