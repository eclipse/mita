package org.eclipse.mita.program.generator

import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.EventHandlerDeclaration

abstract class MainSystemResourceGenerator extends AbstractSystemResourceGenerator {
	/* Returns log_2(ringbufferSize) for target event handler.
	 * Will be used to create a ringbuffer of size 2^(returned value).
	 * This facilitates a really easy ringbuffer implementation.
	 */
	public def int getEventHandlerPayloadQueueSize(EventHandlerDeclaration handler);
}