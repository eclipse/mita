/*
 * Timer.h
 *
 *  Created on: 13.03.2018
 *      Author: administrator
 */

#ifndef SRC_GEN_BASE_TIMER_H_
#define SRC_GEN_BASE_TIMER_H_

#include "Retcode.h"
#ifdef TIMED_APPLICATION
#include "MitaTime.h"
#endif

Exception_T Timer_Connect(void);
Exception_T Timer_Enable(void);
Exception_T Tick_Timer(void);


#endif /* SRC_GEN_BASE_TIMER_H_ */
