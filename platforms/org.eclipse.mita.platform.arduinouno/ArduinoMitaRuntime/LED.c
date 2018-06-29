/*
 * LED.c
 *
 *  Created on: 24.05.2018
 *      Author: rherrmann
 */

#include "LED.h"
#include <avr/io.h>

Exception_T LED_Connect(void) {
	Exception_T retcode = STATUS_OK;
	return retcode;
}

Exception_T LED_Enable(Color_T color){
	switch (color){
	case LED_Y:{
		DDRD |= _BV(DDD4); // Pin 4
		return STATUS_OK;
	}
	case LED_O:{
		DDRD |= _BV(DDD5); // Pin 5
		return STATUS_OK;
	}
	case LED_R:{
		DDRD |= _BV(DDD6); // Pin 6
		return STATUS_OK;
	}
	default:
		break;
	}
	return STATUS_OK;
}

Exception_T LED_Switch(Color_T color, Command_T on){
	switch(color){
	case LED_Y:{
		if (on == LED_COMMAND_ON){
			PORTD |= _BV(PORTD4);
		} else {
			PORTD &= ~_BV(PORTD4);
		}
		return STATUS_OK;
	}
	case LED_O:{
		if (on == LED_COMMAND_ON){
			PORTD |= _BV(PORTD5);
		} else {
			PORTD &= ~_BV(PORTD5);
		}
		return STATUS_OK;
	}
	case LED_R:{
		if (on == LED_COMMAND_ON){
			PORTD |= _BV(PORTD6);
		} else {
			PORTD &= ~_BV(PORTD6);
		}
		return STATUS_OK;
	}
	}
	return STATUS_OK;
}
