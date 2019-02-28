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

#include "GPIO.h"
/*
 * Selected GPIO will be initialized as an IN/OUTPUT
 */
Exception_T GPIO_Connect(Port_T port, Mode_T mode){
	pinMode(port, mode);

	return STATUS_OK;
}

/*
 * Selected GPIO will be set to logical one (HIGH)
 */
Exception_T setGPIO(Port_T port){
	 digitalWrite(port, HIGH);

	return STATUS_OK;
}

/*
 * Selected GPIO will be set to logical zero (LOW)
 */
Exception_T unsetGPIO(Port_T port){
	 digitalWrite(port, LOW);

	return STATUS_OK;
}

/*
 * Reading selected GPIO
 */
Exception_T readGPIO(Port_T port, bool *result){
	int8_t status = 0;
	status = digitalRead(port);
	if(status == LOW) {
		*result = false;
	} else {
		*result = true;
	}

	return STATUS_OK;
}

