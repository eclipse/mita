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

#include "Button.h"


#include "avr/io.h"
#include <util/delay.h>
#include <avr/interrupt.h>
#include <avr/sleep.h>


static void (*ButtonOnePressed)(bool val);
static void (*ButtonOneReleased)(bool val);
static void (*ButtonTwoPressed)(bool val);
static void (*ButtonTwoReleased)(bool val);

/**
 * Connects both buttons.
 */
Exception_T Button_Connect(void) {
	DDRD &=~ _BV(DDD2); 	// PD2 pin to 0
	PORTD |= _BV(PORTD2); 	// raise internal pullup

	DDRD &=~ _BV(DDD3); 	// PD2 pin to 0
	PORTD |= _BV(PORTD3); 	// raise internal pullup

	return STATUS_OK;
}

/**
 * Enables the specific button and connects the pressed or released event.
 */
Exception_T Button_Enable(ButtonNumber_T button, void* function, bool pressed) {
	switch (button) {
	case BUTTON_1: {
		if (pressed == true){
			ButtonOnePressed = function;
		} else {
			ButtonOneReleased = function;
		}
		cli();
		EICRA |= _BV(ISC00);	// Change edge of INT0 generates Interrupt
		EIMSK |= _BV(INTF0);	// mask INT0 interrupt
		sei();
		return STATUS_OK;
	}
	case BUTTON_2: {
		if (pressed == true){
			ButtonTwoPressed = function;
		} else {
			ButtonTwoReleased = function;
		}
		cli();
		EICRA |= _BV(ISC10); 	// Change edge of INT0 generates Interrupt
		EIMSK |= _BV(INTF1);	// mask INT0 interrupt
		sei();
		return STATUS_OK;
	}
	default:
		break;
	}
	return STATUS_OK;
}

/**
 * Result is true, if the button is pressed. Gives the current state of the button.
 */
ButtonState_T Button_GetState(ButtonNumber_T button){
	uint8_t state = UNDEFINED_STATE;
	switch (button) {
		case BUTTON_1: {
			state = (PIND & _BV(PIND3)) > 0 ? HIGH : LOW;
			return state;
		}
		case BUTTON_2: {
			state = (PIND & _BV(PIND3)) > 0 ? HIGH : LOW;
			return state;
		}
		default:
			break;
		}
		return UNDEFINED_STATE;
}

/**
 * Interrupt Service Routine for button_one. Currently, there is no debounce implemeted. 
 */
ISR(INT0_vect){
	volatile int oldState = 0;
	volatile int currentState = 0;
	oldState = (PIND & _BV(PIND2)) > 0 ? HIGH : LOW;
//	sei();
//	_delay_ms(50);
//	cli();
	currentState = (PIND & _BV(PIND2)) > 0 ? HIGH : LOW;
	if (LOW == oldState && LOW == currentState) {
		ButtonOnePressed(true);
	} else if (HIGH == oldState && HIGH == currentState){
		ButtonOneReleased(true);
	}
}

/**
 * Interrupt Service Routine for button_two. Currently, there is no debounce implemeted. 
 */
ISR(INT1_vect){
	volatile int oldState = 0;
	volatile int currentState = 0;
	oldState = (PIND & _BV(PIND3)) > 0 ? HIGH : LOW;
//	sei();
//	_delay_ms(50);
//	cli();
	currentState = (PIND & _BV(PIND3)) > 0 ? HIGH : LOW;
	if (LOW == oldState && LOW == currentState) {
		ButtonTwoPressed(true);
	} else if (HIGH == oldState && HIGH == currentState){
		ButtonTwoReleased(true);
	}
}
