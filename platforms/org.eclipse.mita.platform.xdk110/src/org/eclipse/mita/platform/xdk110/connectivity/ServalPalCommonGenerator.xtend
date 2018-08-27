/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

public class ServalPalCommonGenerator {

		#define TASK_PRIORITY_SERVALPAL_CMD_PROC            UINT32_C(3)
		#define TASK_STACK_SIZE_SERVALPAL_CMD_PROC          UINT32_C(600)
		#define TASK_QUEUE_LEN_SERVALPAL_CMD_PROC           UINT32_C(10)

        Retcode_T retcode = RETCODE_OK;

		static CmdProcessor_T ServalPALCmdProcessorHandle;
		static CmdProcessor_T flag = true;
		ServalPalWiFi_StateChangeInfo_T stateChangeInfo = { SERVALPALWIFI_OPEN, 0 };

	    public def Retcode_T ServalPal_Call() {
		if(flag){
	   	    retcode = CmdProcessor_Initialize(&ServalPALCmdProcessorHandle, "Serval PAL", TASK_PRIORITY_SERVALPAL_CMD_PROC, TASK_STACK_SIZE_SERVALPAL_CMD_PROC, TASK_QUEUE_LEN_SERVALPAL_CMD_PROC);
    	    if (retcode == RETCODE_OK){
    	        retcode = ServalPal_Setup(ServalPALCmdProcessorHandle)
    	        if (retcode != RETCODE_OK)
		        {
			        return retcode;
		        }
	    	}
	      	else{
	      	   return retcode;
	      	}   
	      	
    	else{
			flag = true;
    	}

		.addHeader("BCDS_CmdProcessor.h", true, IncludePath.HIGH_PRIORITY)
		.addHeader("BCDS_ServalPal.h", true, IncludePath.HIGH_PRIORITY)

		return result
	}
}
