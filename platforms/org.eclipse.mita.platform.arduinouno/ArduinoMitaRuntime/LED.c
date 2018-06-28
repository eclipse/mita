/*
 * LED.c
 *
 *  Created on: 24.05.2018
 *      Author: rherrmann
 */

#include "LED.h"
#include <avr/io.h>

Retcode_T LED_Connect(void) {
	Retcode_T retcode = RETCODE_OK;
	return retcode;
}

Retcode_T LED_Enable(uint8_t color){
	switch (color){
	case LED_Y:{
		DDRD |= _BV(DDD4); // Pin 4
		return RETCODE_OK;
	}
	case LED_O:{
		DDRD |= _BV(DDD5); // Pin 5
		return RETCODE_OK;
	}
	case LED_R:{
		DDRD |= _BV(DDD6); // Pin 6
		return RETCODE_OK;
	}
	default:
		break;
	}
	return RETCODE_OK;
}

Retcode_T LED_Switch(uint8_t color, uint8_t on){
	switch(color){
	case LED_Y:{
		if (on == LED_COMMAND_ON){
			PORTD |= _BV(PORTD4);
		} else {
			PORTD &= ~_BV(PORTD4);
		}
		return RETCODE_OK;
	}
	case LED_O:{
		if (on == LED_COMMAND_ON){
			PORTD |= _BV(PORTD5);
		} else {
			PORTD &= ~_BV(PORTD5);
		}
		return RETCODE_OK;
	}
	case LED_R:{
		if (on == LED_COMMAND_ON){
			PORTD |= _BV(PORTD6);
		} else {
			PORTD &= ~_BV(PORTD6);
		}
		return RETCODE_OK;
	}
	}
	return RETCODE_OK;
}
