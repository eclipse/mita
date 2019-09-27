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

package org.eclipse.mita.program.generator

import com.google.inject.Inject
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.xtext.generator.IFileSystemAccess2

/**
 * Base interface for Mita component generators.
 */
abstract class AbstractSystemResourceGenerator implements IGenerator {
	
	/**
	 * Provides codefragments during code generation.
	 */
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	protected CompilationContext context;
	
	/**
	 * The system resource to generate the setup code for the event handler registered to events of this component.
	 */
	protected AbstractSystemResource component;
	
	/**
	 * The user-specified setup
	 */
	protected SystemResourceSetup setup;
	
	/**
	 * The configuration of the component we're about to generate code for.
	 */
	protected IComponentConfiguration configuration;
	
	/**
	 * All user-specified event handler concerning this component 
	 */
	protected Iterable<EventHandlerDeclaration> eventHandler;
	
	/**
	 * Prepares this generator for producing code by supplying all contextual information for doing so.
	 */
	public def void prepare(CompilationContext context, AbstractSystemResource component, SystemResourceSetup setup, IComponentConfiguration config, Iterable<EventHandlerDeclaration> eventHandler) {
		this.context = context;
		this.component = component;
		this.setup = setup;
		this.configuration = config;
		this.eventHandler = eventHandler;
	}
	
	/**
	 * Generates the body of the setup function of a system resource. In the setup function
	 * the resource needs to be configured and callbacks registered. However, the resource
	 * must NOT call those callbacks after the setup function has was executed. 
	 * 
	 * @return the generated code
	 */
	def CodeFragment generateSetup();
	
	/**
	 * Generates the body of the enable function of a system resource.
	 * The enable function is like a "go live" of the system resource. After it was
	 * executed the system resource may trigger callbacks.
	 * 
	 * @return the generated code
	 */
	def CodeFragment generateEnable();
	
	/**
	 * Generates custom additional content for the component header file.
	 * Implementors can use this to register function prototypes for access
	 * functions, or constants needed by the generated code. The default implementation
	 * returns an empty code fragment.
	 * 
	 * @param context the system resource to generate header content for
	 * @return the generated code
	 */
	def CodeFragment generateAdditionalHeaderContent() {
		return CodeFragment.EMPTY;
	}
	
	/**
	 * Generates custom additional content for the component implementation.
	 * Implementors can use this to implement access or other functions
	 * needed by the generated code. The default implementation returns
	 * an empty code fragment.
	 * 
	 * @param context the system resource to generate implementation for
	 * @return the generated code
	 */
	def CodeFragment generateAdditionalImplementation() {
		return CodeFragment.EMPTY;
	}
	
	public def Iterable<String> generateAdditionalFiles(IFileSystemAccess2 fsa) {
		return #[];
	}
	
	/**
	 * Generates code which prepares the subsequent access to a sensor modality. The
	 * generator framework ensures that access preparation code is requested only once
	 * per block, so that nested blocks (hence, scopes) have all variables declared in
	 * this code available.
	 * 
	 * @param accessPreparation The access preparation statement listing the modalities
	 * 				  we would like to access, as well as the system resource we would like
	 * 				  to access those resources on. This object can also be used to find
	 * 				  the program context we're in. For example when generating exception
	 * 				  handler code one needs to find if we're in a try statement or not.
	 * @return the generated code
	 */
	def CodeFragment generateAccessPreparationFor(ModalityAccessPreparation accessPreparation) {
		throw new UnsupportedOperationException("This generator does not support modalities. This is a problem of the platform implementation.");	
	}
	
	/**
	 * Generates the access code for a system resource modality, using the previously generated
	 * access preparation code.
	 * 
	 * <p><b>Implementors beware</b> that this function expected to return a C expression only,
	 * preferably a variable name.</p> 
	 * 
	 * @param modality The modality to generate the access code for
	 * @return the generated code
	 */
	def CodeFragment generateModalityAccessFor(ModalityAccess modality) {
		throw new UnsupportedOperationException("This generator does not support modalities. This is a problem of the platform implementation.");
	}
	
	
	/**
	 * Generates the setter code for a signal instance.
	 * 
	 * @param signalInstance the signal instance for which we are to generate code for
	 * @param valueVariableName the name of the C variable from which the generated code must take the value to set
	 * 
	 * @return the generated code
	 */
	def CodeFragment generateSignalInstanceSetter(SignalInstance signalInstance, String valueVariableName) {
		throw new UnsupportedOperationException("This generator does not support signals. This is a problem of the platform implementation.");
	}
	
	/**
	 * Generates the getter code for a signal instance.
	 * 
	 * @param signalInstance the signal instance for which we are to generate code for
	 * @param valueVariableName the name of the C variable in which the generated code must store the result/current signal value
	 * 
	 * @return the generated code
	 */
	def CodeFragment generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		throw new UnsupportedOperationException("This generator does not support signals. This is a problem of the platform implementation.");
	}

}
