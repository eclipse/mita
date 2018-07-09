/********************************************************************************
 * Copyright (c) 2018 itemis AG.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    itemis AG - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/
 
#include "Timer.h"

#include "avr/interrupt.h"

/*
 * Timer will be initialized. Interrupt every 1 ms.
 */
Exception_T Timer_Connect(void) {
	cli();

	OCR1A = 1999;
	TCCR1B |= _BV(WGM12);
	TCCR1B |= _BV(CS11);
	sei();

	return STATUS_OK;
}

/*
 * Timer interrupts are turned on.
 */
Exception_T Timer_Enable(void) {
	cli();
	TIMSK1 |= _BV(OCIE1A);
	sei();
	return STATUS_OK;
}

/*
 * Interrupt Service Routine for Timer. Tick_Timer() function will only get
 * generated if there are time depending events within the mita application.
 */
ISR(TIMER1_COMPA_vect) {
	#ifdef TIMED_APPLICATION
	Tick_Timer();
	#endif
}
