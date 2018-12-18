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

static void (*ButtonOnePressed)(bool val);
static void (*ButtonOneReleased)(bool val);
static void (*ButtonTwoPressed)(bool val);
static void (*ButtonTwoReleased)(bool val);

static void Button1InterruptCallback(void);
static void Button2InterruptCallback(void);

/**
 * Connects both buttons.
 */
Exception_T Button_Connect(void) {
	pinMode(BUTTON_1, INPUT_PULLUP);
	pinMode(BUTTON_2, INPUT_PULLUP);

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
		attachInterrupt(BUTTON_1, Button1InterruptCallback, CHANGE);
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
		attachInterrupt(BUTTON_2, Button2InterruptCallback, CHANGE);
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
	return digitalRead(button);
}

/**
 * Interrupt Service Routine for button_one. Currently, there is no debounce implemeted. 
 */
static void Button1InterruptCallback(void){
	volatile int oldState = 0;
	volatile int currentState = 0;
	oldState = digitalRead(2);
	currentState = digitalRead(BUTTON_1);
	if (LOW == oldState && LOW == currentState) {
		ButtonOnePressed(true);
	} else if (HIGH == oldState && HIGH == currentState){
		ButtonOneReleased(true);
	}
}

/**
 * Interrupt Service Routine for button_two. Currently, there is no debounce implemeted. 
 */
static void Button2InterruptCallback(void){
	volatile int oldState = 0;
	volatile int currentState = 0;
	oldState = digitalRead(3);
	currentState = digitalRead(BUTTON_2);
	if (LOW == oldState && LOW == currentState) {
		ButtonTwoPressed(true);
	} else if (HIGH == oldState && HIGH == currentState){
		ButtonTwoReleased(true);
	}
}
