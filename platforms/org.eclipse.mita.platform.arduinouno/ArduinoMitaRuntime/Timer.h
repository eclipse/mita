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

#ifndef SRC_GEN_BASE_TIMER_H_
#define SRC_GEN_BASE_TIMER_H_

#include "Retcode.h"
#include "MitaEvents.h"
#ifdef TIMED_APPLICATION
#include "MitaTime.h"
#endif

/*
 * Timer will be initialized. Interrupt every 1 ms.
 */
Exception_T Timer_Connect(void);

/*
 * Timer interrupts are turned on.
 */
Exception_T Timer_Enable(void);

/*
 * Interrupt Service Routine for Timer. Tick_Timer() function will only get
 * generated if there are time depending events within the mita application.
 */
Exception_T Tick_Timer(void);


#endif /* SRC_GEN_BASE_TIMER_H_ */
