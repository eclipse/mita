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
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.SystemResourceEvent
import org.eclipse.mita.program.SystemEventSource
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IComponentConfiguration
import org.eclipse.mita.program.generator.IPlatformExceptionGenerator
import org.eclipse.mita.program.generator.ProgramDslTraceExtensions
import org.eclipse.mita.program.generator.TypeGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2

class SystemResourceHandlingGenerator {

	@Inject
	protected extension GeneratorUtils
	
	@Inject
	protected GeneratorRegistry registry;
	
	@Inject(optional = true)
	protected IPlatformExceptionGenerator exceptionGenerator

    @Inject
    protected CodeFragmentProvider codeFragmentProvider
    
    @Inject
    protected TypeGenerator typeGenerator
	
	@Inject
	protected extension ProgramDslTraceExtensions

	def generateAdditionalFiles(IFileSystemAccess2 fsa, CompilationContext context, EObject obj) {
		val componentAndSetup = obj.getComponentAndSetup(context);
		val component = componentAndSetup.key;
		val setup = componentAndSetup.value;
		
		val internalGenerator = registry.getGenerator(component);
		if(internalGenerator !== null) {
			internalGenerator.prepare(component, setup, getConfiguration(context, component, setup), getRelevantEventHandler(context, component));			
		}
		internalGenerator.generateAdditionalFiles(fsa);
	}

	def generateHeader(CompilationContext context, EObject obj) {
		val componentAndSetup = obj.getComponentAndSetup(context);
		val component = componentAndSetup.key;
		val setup = componentAndSetup.value;
		
		val internalGenerator = registry.getGenerator(component);
		if(internalGenerator !== null) {
			internalGenerator.prepare(component, setup, getConfiguration(context, component, setup), getRelevantEventHandler(context, component));			
		}
		
		val exceptionType = exceptionGenerator.exceptionType;
		val name = EcoreUtil.getID(component);
		
		val cgn = obj.trace
		cgn.children.add(
			codeFragmentProvider.create('''
				/**
				 * Sets up the «name».
				 */
				«exceptionType» «(setup ?: component).setupName»(void);
				
				/**
				 * Enables the «name» sensor.
				 */
				«exceptionType» «(setup ?: component).enableName»(void);

				«IF setup !== null»
				«FOR signalInstance : setup?.signalInstances»
				«val signalType = BaseUtils.getType(signalInstance).sigInstType2»
				/**
				 * Provides read access to «signalInstance.name».
				 */
				«exceptionType» «signalInstance.readAccessName»(«typeGenerator.code(obj, signalType)»* result);

				«IF signalInstance.writeable»
				/**
				 * Provides write access to «signalInstance.name».
				 */
				«exceptionType» «signalInstance.writeAccessName»(«typeGenerator.code(obj, signalType)»* result);
				«ENDIF»
				«ENDFOR»
				«ENDIF»
				
				«internalGenerator?.generateAdditionalHeaderContent()»
			''')
			.toHeader(context, '''«component.baseName.toUpperCase»_«name.toUpperCase»_H'''))
		return cgn;
	}
	
	dispatch def AbstractType getSigInstType(AbstractType type) {
		return type;
	}
	
	dispatch def AbstractType getSigInstType(FunctionType type) {
		return type.to.sigInstType2;
	}
	
	dispatch def AbstractType getSigInstType2(AbstractType type) {
		return type;
	}
	dispatch def AbstractType getSigInstType2(FunctionType type) {
		return type.to.sigInstType3;
	}
	
	dispatch def AbstractType getSigInstType3(AbstractType type) {
		return type;
	}
	dispatch def AbstractType getSigInstType3(TypeConstructorType type) {
		if(type.name == "siginst" && type.typeArguments.tail.size > 0) {
			return type.typeArguments.head;
		}
		return type;
	}
	
	def generateImplementation(CompilationContext context, EObject obj) {
		val componentAndSetup = obj.getComponentAndSetup(context);
		val component = componentAndSetup.key;
		val setup = componentAndSetup.value;
		
		val internalGenerator = registry.getGenerator(component);
		if(internalGenerator !== null) {
			internalGenerator.prepare(component, setup, getConfiguration(context, component, setup), getRelevantEventHandler(context, component));			
		}
		
		val exceptionType = exceptionGenerator.exceptionType;
		
		val cgn = obj.trace
		cgn.children.add(
			codeFragmentProvider.create('''
				«exceptionType» «(setup ?: component).setupName»(void)
				{
					«internalGenerator?.generateSetup()»
					
					return NO_EXCEPTION;
				}
				
				«exceptionType» «(setup ?: component).enableName»(void)
				{
					«internalGenerator?.generateEnable()»
					
					return NO_EXCEPTION;
				}
				
				«IF setup !== null»
				«FOR signalInstance : setup?.signalInstances»
				«val signalType = BaseUtils.getType(signalInstance).sigInstType2»
				/**
				 * Provides read access to the «signalInstance.name» signal.
				 */
				«exceptionType» «signalInstance.readAccessName»(«typeGenerator.code(obj, signalType)»* result)
				{
					«internalGenerator?.generateSignalInstanceGetter(signalInstance, 'result')»
					
					return NO_EXCEPTION;
				}
				
				«IF signalInstance.writeable»
				/**
				 * Provides write access to the «signalInstance.name» signal.
				 */
				«exceptionType» «signalInstance.writeAccessName»(«typeGenerator.code(obj, signalType)»* value)
				{
					«internalGenerator?.generateSignalInstanceSetter(signalInstance, 'value')»
					
					return NO_EXCEPTION;
				}
				
				«ENDIF»

				«ENDFOR»
				«ENDIF»
				«internalGenerator?.generateAdditionalImplementation()»
			''')
			.addHeader('MitaExceptions.h', false)
			.toImplementation(context))
		return cgn;
	}
	
	protected def IComponentConfiguration getConfiguration(CompilationContext context, AbstractSystemResource component, SystemResourceSetup setup) {
		return new MapBasedComponentConfiguration(component, context, setup);
	}

	protected def getRelevantEventHandler(CompilationContext context, AbstractSystemResource component) {
		return context.allEventHandlers.filter[x |
			val event = x.event;
			val eventSource = if(event instanceof SystemEventSource) {
				event.origin;
			} else {
				return false;
			}
			val subject = if(eventSource instanceof SystemResourceEvent) {
				eventSource.eContainer as AbstractSystemResource;
			} else if(eventSource instanceof AbstractSystemResource) {
				eventSource;
			} else {
				return false;
			}
			val object = if(component instanceof SystemResourceSetup) {
				component.type;
			} else {
				component;
			}
			
			return EcoreUtil.getID(subject) == EcoreUtil.getID(object);
		];
	}
	
}