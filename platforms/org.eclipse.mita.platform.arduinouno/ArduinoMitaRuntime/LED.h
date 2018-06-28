/*
 * LED.h
 *
 *  Created on: 24.05.2018
 *      Author: rherrmann
 */

#ifndef SRC_GEN_BASE_LED_H_
#define SRC_GEN_BASE_LED_H_

#include "Retcode.h"

Retcode_T LED_Connect(void);

Retcode_T LED_Enable(Color_T color);

Retcode_T LED_Switch(Color_T color, Command_T on);

enum {
	LED_Y, LED_O, LED_R
};

enum {
	LED_COMMAND_ON, LED_COMMAND_OFF
};

#endif /* SRC_GEN_BASE_LED_H_ */
