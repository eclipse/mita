/*
 * ARD_Button.h
 *
 *  Created on: 24.05.2018
 *      Author: rherrmann
 */

#ifndef SRC_GEN_BASE_ARD_BUTTON_H_
#define SRC_GEN_BASE_ARD_BUTTON_H_

#include "ARD_Retcode.h"
#include "MitaEvents.h"

#include "avr/io.h"
#include <util/delay.h>
#include <avr/interrupt.h>
#include <avr/sleep.h>

typedef void (*Callback)(uint32_t);

Retcode_T ARD_Button_Connect(void);

Retcode_T ARD_Button_Enable(uint32_t button, void* function, bool pressed);

enum {
	ARD_BUTTON_1, ARD_BUTTON_2
};

#endif /* SRC_GEN_BASE_ARD_BUTTON_H_ */
