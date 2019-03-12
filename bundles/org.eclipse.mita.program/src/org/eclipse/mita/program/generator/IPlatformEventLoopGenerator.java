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

package org.eclipse.mita.program.generator;

import org.eclipse.mita.program.EventHandlerDeclaration;
import org.eclipse.mita.program.generator.CompilationContext;

public interface IPlatformEventLoopGenerator {

	/**
	 * Generates the code which starts the event loop and thus transfers the system
	 * to an operating state.
	 * 
	 * @param context
	 *            the context for which to start the event loop
	 * @return the generated code
	 */
	public CodeFragment generateEventLoopStart(CompilationContext context);

	/**
	 * Generates code which injects a pointer to a function into the event loop.
	 * 
	 * @param context
	 *            The context in which we're working
	 * @param functionName
	 *            the name of the function to enque
	 * @return the generated code which is always treated as raw code.
	 */
	public CodeFragment generateEventLoopInject(CompilationContext context, String functionName);

	/**
	 * Generates the signature of a function which will be enqueued in the event
	 * queue. For example:
	 * 
	 * <pre>
	 * void* userParam1, uint32_t userParam2
	 * </pre>
	 * 
	 * or simply
	 * 
	 * <pre>
	 * void
	 * </pre>
	 * 
	 * depending on the need of the underlying event queue implementation.
	 * 
	 * @param context
	 *            the context we're working with
	 * @return the function signature
	 */
	public CodeFragment generateEventLoopHandlerSignature(CompilationContext context);

	/**
	 * Optionally generates a preamble for a handler function which is executed in
	 * the event loop context.
	 * 
	 * @param context
	 *            the context we're generating this for
	 * @param handler
	 *            the handler we're about to execute
	 * @return the generated code
	 */
	public CodeFragment generateEventLoopHandlerPreamble(CompilationContext context, EventHandlerDeclaration handler);

	/**
	 * Generates code which is prepended to the MitaEvents.h file. Implementors
	 * could use this to maintain a global reference to an event loop handle, or to
	 * register a prototype for the event loop enqueue function.
	 * 
	 * @param context
	 *            the context we're generating code for
	 * @return the generated preamble.
	 */
	public CodeFragment generateEventHeaderPreamble(CompilationContext context);
	
	/**
	 * Generates code which is prepended to the Mita_initialize function. This is prepended after generateEventLoopHandlerPreamble and exception variable declaration.
	 * @param context
	 *            the context we're generating code for
	 * @return the generated preamble.
	 */
	public CodeFragment generateSetupPreamble(CompilationContext context);
	/**
	 * Generates code which is prepended to the Mita_goLive function. This is prepended after generateEventLoopHandlerPreamble and exception variable declaration.
	 * @param context
	 *            the context we're generating code for
	 * @return the generated preamble.
	 */
	public CodeFragment generateEnablePreamble(CompilationContext context);

	public class NullImpl implements IPlatformEventLoopGenerator {

		@Override
		public CodeFragment generateEventLoopStart(CompilationContext context) {
			return CodeFragment.EMPTY;
		}

		@Override
		public CodeFragment generateEventLoopInject(CompilationContext context, String functionName) {
			return CodeFragment.EMPTY;
		}

		@Override
		public CodeFragment generateEventLoopHandlerSignature(CompilationContext context) {
			return CodeFragment.EMPTY;
		}

		@Override
		public CodeFragment generateEventLoopHandlerPreamble(CompilationContext context,
				EventHandlerDeclaration handler) {
			return CodeFragment.EMPTY;
		}

		@Override
		public CodeFragment generateEventHeaderPreamble(CompilationContext context) {
			return CodeFragment.EMPTY;
		}

		@Override
		public CodeFragment generateSetupPreamble(CompilationContext context) {
			return CodeFragment.EMPTY;
		}

		@Override
		public CodeFragment generateEnablePreamble(CompilationContext context) {
			return CodeFragment.EMPTY;
		}
	}
}