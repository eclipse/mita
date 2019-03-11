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

#ifndef SRC_GEN_BASE_BUTTON_H_
#define SRC_GEN_BASE_BUTTON_H_

#include "Retcode.h"
#include "MitaEvents.h"

typedef void (*Callback)(uint32_t);

/**
 * Connects both buttons.
 */
Exception_T Button_Connect(void);

/**
 * Enables the specific button and connects the pressed or released event.
 */
Exception_T Button_Enable(ButtonNumber_T button, void* function, bool pressed);

ButtonState_T Button_GetState(ButtonNumber_T button);

enum {
	BUTTON_1 = 2, BUTTON_2 = 3
};

#endif /* SRC_GEN_BASE_BUTTON_H_ */
