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

#include "GPIO.h"
#include <avr/io.h>

/*
 * Selected GPIO will be initialized as an IN/OUTPUT
 */
Exception_T GPIO_Connect(Port_T port, Mode_T mode){
	// pinMode(port, mode); could be used if arduino.h would be included
	switch(port){
	case p0: {
		if (mode == OUTPUT){
			DDRD |= _BV(DDD0);
		} else {
			DDRD &= ~ _BV(DDD0);
		}
		return STATUS_OK;
	}
	case p1: {
		if (mode == OUTPUT){
			DDRD |= _BV(DDD1);
		} else {
			DDRD &= ~ _BV(DDD1);
		}
		return STATUS_OK;
	}
	case p2: {
		if (mode == OUTPUT){
			DDRD |= _BV(DDD2);
		} else {
			DDRD &= ~ _BV(DDD2);
		}
		return STATUS_OK;
	}
	case p3: {
		if (mode == OUTPUT){
			DDRD |= _BV(DDD3);
		} else {
			DDRD &= ~ _BV(DDD3);
		}
		return STATUS_OK;
	}
	case p4: {
		if (mode == OUTPUT){
			DDRD |= _BV(DDD4);
		} else {
			DDRD &= ~ _BV(DDD4);
		}
		return STATUS_OK;
	}
	case p5: {
		if (mode == OUTPUT){
			DDRD |= _BV(DDD5);
		} else {
			DDRD &= ~ _BV(DDD5);
		}
		return STATUS_OK;
	}
	case p6: {
		if (mode == OUTPUT){
			DDRD |= _BV(DDD6);
		} else {
			DDRD &= ~ _BV(DDD6);
		}
		return STATUS_OK;
	}
	case p7: {
		if (mode == OUTPUT){
			DDRD |= _BV(DDD7);
		} else {
			DDRD &= ~ _BV(DDD7);
		}
		return STATUS_OK;
	}
	case p8: {
		if (mode == OUTPUT){
			DDRB |= _BV(DDB0);
		} else {
			DDRB &= ~ _BV(DDB0);
		}
		return STATUS_OK;
	}
	case p9: {
		if (mode == OUTPUT){
			DDRB |= _BV(DDB1);
		} else {
			DDRB &= ~ _BV(DDB1);
		}
		return STATUS_OK;
	}
	case p10: {
		if (mode == OUTPUT){
			DDRB |= _BV(DDB2);
		} else {
			DDRB &= ~ _BV(DDB2);
		}
		return STATUS_OK;
	}
	case p11: {
		if (mode == OUTPUT){
			DDRB |= _BV(DDB3);
		} else {
			DDRB &= ~ _BV(DDB3);
		}
		return STATUS_OK;
	}
	case p12: {
		if (mode == OUTPUT){
			DDRB |= _BV(DDB4);
		} else {
			DDRB &= ~ _BV(DDB4);
		}
		return STATUS_OK;
	}
	case p13: {
		if (mode == OUTPUT){
			DDRB |= _BV(DDB5);
		} else {
			DDRB &= ~ _BV(DDB5);
		}
		return STATUS_OK;
	}
	}
	return STATUS_OK;
}

/*
 * Selected GPIO will be set to logical one (HIGH)
 */
Exception_T setGPIO(Port_T port){
	// digialWrite(port, HIGH); could be used if arduino.h would be included
	switch(port){
	case p0: {
		PORTD |= _BV(PORTD0);
		return STATUS_OK;
	}
	case p1: {
		PORTD |= _BV(PORTD1);
		return STATUS_OK;
	}
	case p2: {
		PORTD |= _BV(PORTD2);
		return STATUS_OK;
	}
	case p3: {
		PORTD |= _BV(PORTD3);
		return STATUS_OK;
	}
	case p4: {
		PORTD |= _BV(PORTD4);
		return STATUS_OK;
	}
	case p5: {
		PORTD |= _BV(PORTD5);
		return STATUS_OK;
	}
	case p6: {
		PORTD |= _BV(PORTD6);
		return STATUS_OK;
	}
	case p7: {
		PORTD |= _BV(PORTD7);
		return STATUS_OK;
	}
	case p8: {
		PORTB |= _BV(PORTB0);
		return STATUS_OK;
	}
	case p9: {
		PORTB |= _BV(PORTB1);
		return STATUS_OK;
	}
	case p10: {
		PORTB |= _BV(PORTB2);
		return STATUS_OK;
	}
	case p11: {
		PORTB |= _BV(PORTB3);
		return STATUS_OK;
	}
	case p12: {
		PORTB |= _BV(PORTB4);
		return STATUS_OK;
	}
	case p13: {
		PORTB |= _BV(PORTB5);
		return STATUS_OK;
	}
	}
	return STATUS_OK;
}

/*
 * Selected GPIO will be set to logical zero (LOW)
 */
Exception_T unsetGPIO(Port_T port){
	// digialWrite(port, LOW); could be used if arduino.h would be included
	switch(port){
	case p0: {
		PORTD &=~ _BV(PORTD0);
		return STATUS_OK;
	}
	case p1: {
		PORTD &=~ _BV(PORTD1);
		return STATUS_OK;
	}
	case p2: {
		PORTD &=~ _BV(PORTD2);
		return STATUS_OK;
	}
	case p3: {
		PORTD &=~ _BV(PORTD3);
		return STATUS_OK;
	}
	case p4: {
		PORTD &=~ _BV(PORTD4);
		return STATUS_OK;
	}
	case p5: {
		PORTD &=~ _BV(PORTD5);
		return STATUS_OK;
	}
	case p6: {
		PORTD &=~ _BV(PORTD6);
		return STATUS_OK;
	}
	case p7: {
		PORTD &=~ _BV(PORTD7);
		return STATUS_OK;
	}
	case p8: {
		PORTB &=~ _BV(PORTB0);
		return STATUS_OK;
	}
	case p9: {
		PORTB &=~ _BV(PORTB1);
		return STATUS_OK;
	}
	case p10: {
		PORTB &=~ _BV(PORTB2);
		return STATUS_OK;
	}
	case p11: {
		PORTB &=~ _BV(PORTB3);
		return STATUS_OK;
	}
	case p12: {
		PORTB &=~ _BV(PORTB4);
		return STATUS_OK;
	}
	case p13: {
		PORTB &=~ _BV(PORTB5);
		return STATUS_OK;
	}
	}
	return STATUS_OK;
}

/*
 * Reading selected GPIO
 */
Exception_T readGPIO(Port_T port, bool *result){
	//result = digitalRead(port); // could be used, if arduino.h would be included
	switch(port){
	case p0: {
		if((PIND & _BV(PIND0)) > 0) {
			*result = true;
		} else {
			*result = false;
		}
		return STATUS_OK;
	}
	case p1: {
		if((PIND & _BV(PIND1)) > 0) {
			*result = true;
		} else {
			*result = false;
		}
		return STATUS_OK;
	}
	case p2: {
		if((PIND & _BV(PIND2)) > 0) {
			*result = true;
		} else {
			*result = false;
		}
		return STATUS_OK;
	}
	case p3: {
		if((PIND & _BV(PIND3)) > 0) {
			*result = true;
		} else {
			*result = false;
		}
		return STATUS_OK;
	}
	case p4: {
		if((PIND & _BV(PIND4)) > 0) {
			*result = true;
		} else {
			*result = false;
		}
		return STATUS_OK;
	}
	case p5: {
		if((PIND & _BV(PIND5)) > 0) {
			*result = true;
		} else {
			*result = false;
		}
		return STATUS_OK;
	}
	case p6: {
		if((PIND & _BV(PIND6)) > 0) {
			*result = true;
		} else {
			*result = false;
		}
		return STATUS_OK;
	}
	case p7: {
		if((PIND & _BV(PIND7)) > 0) {
			*result = true;
		} else {
			*result = false;
		}
		return STATUS_OK;
	}
	case p8: {
		if((PINB & _BV(PINB0)) > 0) {
			*result = true;
		} else {
			*result = false;
		}
		return STATUS_OK;
	}
	case p9: {
		if((PINB & _BV(PINB1)) > 0) {
			*result = true;
		} else {
			*result = false;
		}
		return STATUS_OK;
	}
	case p10: {
		if((PINB & _BV(PINB2)) > 0) {
			*result = true;
		} else {
			*result = false;
		}
		return STATUS_OK;
	}
	case p11: {
		if((PINB & _BV(PINB3)) > 0) {
			*result = true;
		} else {
			*result = false;
		}
		return STATUS_OK;
	}
	case p12: {
		if((PINB & _BV(PINB4)) > 0) {
			*result = true;
		} else {
			*result = false;
		}
		return STATUS_OK;
	}
	case p13: {
		if((PINB & _BV(PINB5)) > 0) {
			*result = true;
		} else {
			*result = false;
		}
		return STATUS_OK;
	}
	}
	return STATUS_OK;
}

