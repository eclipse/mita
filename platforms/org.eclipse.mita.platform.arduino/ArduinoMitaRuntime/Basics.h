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
 
#ifndef BASICS_H_
#define BASICS_H_

#include <stdint.h>
#include <stdbool.h>
#include "Arduino.h"

#define FALSE (uint8_t)0
#define TRUE (uint8_t)1

typedef uint8_t Color_T;
typedef uint8_t Command_T;
typedef uint32_t ButtonNumber_T;
typedef uint8_t ButtonState_T;

#endif /* BASICS_H_ */
