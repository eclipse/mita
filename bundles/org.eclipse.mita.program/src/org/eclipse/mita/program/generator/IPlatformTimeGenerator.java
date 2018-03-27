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
import org.eclipse.mita.program.TimeIntervalEvent;

public interface IPlatformTimeGenerator {

	/**
	 * Generates the code which sets up the timer structure so that we can serve the
	 * time events specified in the program. After executing this code the platform
	 * must not yet serve the events.
	 * 
	 * @param program
	 *            the program for which to initialize the timers
	 * @return the generated code
	 */
	public CodeFragment generateTimeSetup(CompilationContext context);

	/**
	 * Generates the code which starts all the timers and starts serving the timer
	 * events.
	 * 
	 * @param program
	 *            the program for which to set the timers live
	 * @return the generated code
	 */
	public CodeFragment generateTimeGoLive(CompilationContext context);

	/**
	 * Generates the code which enables this event handler.
	 * 
	 * <p>
	 * <b>Note: </b> This method will only be called with event handlers whose event
	 * are of time {@link TimeIntervalEvent}
	 * </p>
	 * 
	 * @param program
	 *            The program we're generating code for
	 * @param handler
	 *            The event handler to generate the enable code for
	 * @return the generated code
	 */
	public CodeFragment generateTimeEnable(CompilationContext context, EventHandlerDeclaration handler);

	public class NullImpl implements IPlatformTimeGenerator {

		@Override
		public CodeFragment generateTimeSetup(CompilationContext context) {
			return CodeFragment.EMPTY;
		}

		@Override
		public CodeFragment generateTimeGoLive(CompilationContext context) {
			return CodeFragment.EMPTY;
		}

		@Override
		public CodeFragment generateTimeEnable(CompilationContext context, EventHandlerDeclaration handler) {
			return CodeFragment.EMPTY;
		}
	}
}