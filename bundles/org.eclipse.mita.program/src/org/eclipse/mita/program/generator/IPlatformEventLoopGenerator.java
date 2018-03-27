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

public interface IPlatformEventLoopGenerator {

	/**
	 * Generates the code which starts the event loop and thus transfers the system
	 * to an operating state.
	 * 
	 * @param program
	 *            the program for which to start the event loop
	 * @return the generated code
	 */
	public CodeFragment generateEventLoopStart(CompilationContext context);

	/**
	 * Generates code which injects a pointer to a function into the event loop.
	 * 
	 * @param program
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
	 * @param program
	 *            the program we're working with
	 * @return the function signature
	 */
	public CodeFragment generateEventLoopHandlerSignature(CompilationContext context);

	/**
	 * Optionally generates a preamble for a handler function which is executed in
	 * the event loop context.
	 * 
	 * @param program
	 *            the program we're generating this for
	 * @param handler
	 *            the handler we're about to execute
	 * @return the generated code or null if no preamble is needed
	 */
	public CodeFragment generateEventLoopHandlerPreamble(CompilationContext context, EventHandlerDeclaration handler);

	/**
	 * Generates code which is prepended to the MitaEvents.h file. Implementors
	 * could use this to maintain a global reference to an event loop handle, or to
	 * register a prototype for the event loop enqueue function.
	 * 
	 * @param program
	 *            the program we're generating code for
	 * @return the generated preamble. Can be null if none is needed.
	 */
	public CodeFragment generateEventHeaderPreamble(CompilationContext context);

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

	}
}