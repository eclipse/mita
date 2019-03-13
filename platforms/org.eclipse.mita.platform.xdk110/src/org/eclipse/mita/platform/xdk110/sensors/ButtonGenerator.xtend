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

package org.eclipse.mita.platform.xdk110.sensors

import com.google.inject.Inject
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.SystemEventSource
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.GeneratorUtils

class ButtonGenerator extends AbstractSystemResourceGenerator {

	@Inject
	protected extension GeneratorUtils

	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
    override generateSetup() {
        codeFragmentProvider.create('''
            return BSP_Button_Connect();
        ''')
            .addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
            .addHeader('BCDS_CmdProcessor.h', true)
            .addHeader('BSP_BoardType.h', true, IncludePath.HIGH_PRIORITY)
            .addHeader('BCDS_BSP_Button.h', true)
            .addHeader('MitaEvents.h', true)
            .setPreamble('''
			«FOR handlergrp : eventHandler.groupBy[it.sensorInstance.buttonNumber].values»
			void «handlergrp.head.internalHandlerName»(uint32_t data)
			{
				«FOR idx_handler: handlergrp.indexed»
				«IF #["pressed", "released"].contains((idx_handler.value.event as SystemEventSource)?.source?.name)»
				«IF idx_handler.key > 0»else «ENDIF»if(data == «getButtonStatusEnumName(idx_handler.value)») {
					Retcode_T retcode = CmdProcessor_enqueueFromIsr(&Mita_EventQueue, «idx_handler.value.handlerName», NULL, data);
					if(retcode != RETCODE_OK)
					{
						Retcode_RaiseErrorFromIsr(retcode);
					}
				}
				«ENDIF»
            	«ENDFOR»
				«val changedHandlers = handlergrp.filter[(it.event as SystemEventSource)?.source?.name == "changed"]»
				«FOR changedHandler: changedHandlers»
				// enqueue boolean in ringbuffer
				Retcode_T retcode = CmdProcessor_enqueueFromIsr(&Mita_EventQueue, «changedHandler.handlerName», NULL, data);
				if(retcode != RETCODE_OK)
				{
					Retcode_RaiseErrorFromIsr(retcode);
				}
            	«ENDFOR»
			}
			
			«ENDFOR»
            ''')
    }
    
    override generateEnable() {
        codeFragmentProvider.create('''
        Retcode_T retcode = NO_EXCEPTION;

        retcode = BSP_Button_Enable((uint32_t) BSP_XDK_BUTTON_«eventHandler.head.sensorInstance.buttonNumber», «eventHandler.head.internalHandlerName»);
        if(retcode != NO_EXCEPTION) return retcode;
        ''')
    }
    
    private def getInternalHandlerName(EventHandlerDeclaration handler) {
        '''Button«handler.sensorInstance.buttonName.toFirstUpper»_OnEvent'''
    }
    
    private def String getButtonStatusEnumName(EventHandlerDeclaration handler) {
    	return "BSP_XDK_BUTTON_" + if((handler.event as SystemEventSource)?.source?.name == "released") {
    		"RELEASE"
    	}
    	else {
    		"PRESS"
    	}
    }
    
    private def getSensorInstance(EventHandlerDeclaration declaration) {
        val event = declaration.event as SystemEventSource;
        return event.origin as AbstractSystemResource;
    }
    
    private def getButtonName(AbstractSystemResource origin) {
        return origin.name.split('_').last;
    }
    
    private def int getButtonNumber(AbstractSystemResource declaration) {
        return if(declaration.buttonName == 'one') {
            1
        } else {
            2
        }
    }
    
	override generateAccessPreparationFor(ModalityAccessPreparation preparation) {
		return CodeFragment.EMPTY;
	}
    
	override generateModalityAccessFor(ModalityAccess modality) {
		codeFragmentProvider.create('''(BSP_Button_GetState((uint32_t) BSP_XDK_BUTTON_«component.buttonNumber») == 1)''')
            .addHeader('BSP_BoardType.h', true, IncludePath.HIGH_PRIORITY)
            .addHeader('BCDS_BSP_Button.h', true);
    }
    
    
}