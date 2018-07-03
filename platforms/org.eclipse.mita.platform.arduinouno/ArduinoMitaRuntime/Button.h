/*
 * Button.h
 *
 *  Created on: 24.05.2018
 *      Author: rherrmann
 */

#ifndef SRC_GEN_BASE_BUTTON_H_
#define SRC_GEN_BASE_BUTTON_H_

#include "Retcode.h"
#include "MitaEvents.h"

typedef void (*Callback)(uint32_t);

Exception_T Button_Connect(void);

Exception_T Button_Enable(uint32_t button, void* function, bool pressed);

extern void setHandleEveryButton_onePressed1_flag(bool val);

enum {
	BUTTON_1, BUTTON_2
};

#endif /* SRC_GEN_BASE_BUTTON_H_ */
