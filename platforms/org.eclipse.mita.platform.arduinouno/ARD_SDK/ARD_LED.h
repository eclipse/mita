/*
 * ARD_LED.h
 *
 *  Created on: 24.05.2018
 *      Author: rherrmann
 */

#ifndef SRC_GEN_BASE_ARD_LED_H_
#define SRC_GEN_BASE_ARD_LED_H_

#include "ARD_Retcode.h"
#include <avr/io.h>

Retcode_T ARD_LED_Connect(void);

Retcode_T ARD_LED_Enable(uint8_t color);

Retcode_T ARD_LED_Switch(uint8_t color, uint8_t on);

enum {
	ARD_LED_Y, ARD_LED_O, ARD_LED_R
};

enum {
	LED_COMMAND_ON, LED_COMMAND_OFF
};

#endif /* SRC_GEN_BASE_ARD_LED_H_ */
