/*
 * Timer.h
 *
 *  Created on: 13.03.2018
 *      Author: administrator
 */

#ifndef SRC_GEN_BASE_TIMER_H_
#define SRC_GEN_BASE_TIMER_H_

#include "Retcode.h"
#include "MitaTime.h"

Retcode_T Timer_Connect(void);
Retcode_T Timer_Enable(void);
Retcode_T Tick_Timer(void);


#endif /* SRC_GEN_BASE_TIMER_H_ */
