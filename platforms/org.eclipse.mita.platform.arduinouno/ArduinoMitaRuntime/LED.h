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

#ifndef SRC_GEN_BASE_LED_H_
#define SRC_GEN_BASE_LED_H_

#include "Retcode.h"

/**
 * Connects the LEDs. This is currently an empty implementation.
 */
Exception_T LED_Connect(void);

/**
 * Single LED will be connected.
 */
Exception_T LED_Enable(Color_T color);

/*
 * A single LED will be switched on or off depending on the command.
 */
Exception_T LED_Switch(Color_T color, Command_T on);

enum {
	LED_Y, LED_O, LED_R
};

enum {
	LED_COMMAND_ON, LED_COMMAND_OFF
};

#endif /* SRC_GEN_BASE_LED_H_ */
