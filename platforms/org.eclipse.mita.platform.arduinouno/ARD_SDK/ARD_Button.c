/*
 * ARD_Button.c
 *
 *  Created on: 24.05.2018
 *      Author: rherrmann
 */

#include "ARD_Button.h"

static void (*ButtonOnePressed)(void);
static void (*ButtonOneReleased)(void);
static void (*ButtonTwoPressed)(void);
static void (*ButtonTwoReleased)(void);


Retcode_T ARD_Button_Connect(void) {
	DDRD &=~ _BV(DDD2); 	// PD2 pin to 0
	PORTD |= _BV(PORTD2); 	// raise internal pullup
//
	DDRD &=~ _BV(DDD3); 	// PD2 pin to 0
	PORTD |= _BV(PORTD3); 	// raise internal pullup

	return RETCODE_OK;
}

Retcode_T ARD_Button_Enable(uint32_t button, void* function, bool pressed) {
	switch (button) {
	case ARD_BUTTON_1: {
		if (pressed == true){
			ButtonOnePressed = function;
		} else {
			ButtonOneReleased = function;
		}
		cli();
		EICRA |= _BV(ISC00);	// Change edge of INT0 generates Interrupt
		EIMSK |= _BV(INTF0);	// mask INT0 interrupt
		sei();
		return RETCODE_OK;
	}
	case ARD_BUTTON_2: {
		if (pressed == true){
			ButtonTwoPressed = function;
		} else {
			ButtonTwoReleased = function;
		}
		cli();
		EICRA |= _BV(ISC10); 	// Change edge of INT0 generates Interrupt
		EIMSK |= _BV(INTF1);	// mask INT0 interrupt
		sei();
		return RETCODE_OK;
	}
	default:
		break;
	}
	return RETCODE_OK;
}

uint8_t ARD_Button_GetState(uint32_t button){
	uint8_t state = UNDEFINED_STATE;
	switch (button) {
		case ARD_BUTTON_1: {
			state = (PIND & _BV(PIND3)) > 0 ? HIGH : LOW;
			return state;
		}
		case ARD_BUTTON_2: {
			state = (PIND & _BV(PIND3)) > 0 ? HIGH : LOW;
			return state;
		}
		default:
			break;
		}
		return UNDEFINED_STATE;
}

ISR(INT0_vect){
	volatile int oldState = 0;
	volatile int currentState = 0;
	oldState = (PIND & _BV(PIND2)) > 0 ? HIGH : LOW;
//	sei();
//	_delay_ms(50);
//	cli();
	currentState = (PIND & _BV(PIND2)) > 0 ? HIGH : LOW;
	if (LOW == oldState && LOW == currentState) {
		ButtonOnePressed();
	} else if (HIGH == oldState && HIGH == currentState){
		ButtonOneReleased();
	}
}

ISR(INT1_vect){
	volatile int oldState = 0;
	volatile int currentState = 0;
	oldState = (PIND & _BV(PIND3)) > 0 ? HIGH : LOW;
//	sei();
//	_delay_ms(50);
//	cli();
	currentState = (PIND & _BV(PIND3)) > 0 ? HIGH : LOW;
	if (LOW == oldState && LOW == currentState) {
		ButtonTwoPressed();
	} else if (HIGH == oldState && HIGH == currentState){
		ButtonTwoReleased();
	}
}
