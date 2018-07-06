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

#ifndef SRC_GEN_BASE_GPIO_H_
#define SRC_GEN_BASE_GPIO_H_

#include "Retcode.h"

typedef uint32_t Port_T;
typedef uint8_t Mode_T;

#define INPUT (Mode_T)0
#define OUTPUT (Mode_T)1

/*
 * Selected GPIO will be initialized as an IN/OUTPUT
 */
Exception_T GPIO_Connect(Port_T port, Mode_T mode);

/*
 * Selected GPIO will be set to logical one (HIGH)
 */
Exception_T setGPIO(Port_T port);

/*
 * Selected GPIO will be set to logical zero (LOW)
 */
Exception_T unsetGPIO(Port_T port);

/*
 * Reading selected GPIO
 */
Exception_T readGPIO(Port_T port, bool *result);

enum{
	p0,
	p1,
	p2,
	p3,
	p4,
	p5,
	p6,
	p7,
	p8,
	p9,
	p10,
	p11,
	p12,
	p13
};

#endif /* SRC_GEN_BASE_GPIO_H_ */
