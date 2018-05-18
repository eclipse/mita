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

import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.SystemEventSource
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.GeneratorUtils
import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.ModalityAccess

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
            «FOR handler : eventHandler»
            void «handler.internalHandlerName»(uint32_t data)
            {
            	if(data == BSP_XDK_BUTTON_PRESS) {
            		Retcode_T retcode = CmdProcessor_enqueueFromIsr(&Mita_EventQueue, «handler.handlerName», NULL, data);
                    if(retcode != RETCODE_OK)
                    {
                        Retcode_raiseErrorFromIsr(retcode);
                    }
            	}
            }
            
            «ENDFOR»
            ''')
    }
    
    override generateEnable() {
        codeFragmentProvider.create('''
        Retcode_T retcode = NO_EXCEPTION;
        
        «FOR handler : eventHandler»
        retcode = BSP_Button_Enable((uint32_t) BSP_XDK_BUTTON_«handler.sensorInstance.buttonNumber», «handler.internalHandlerName»);
        if(retcode != NO_EXCEPTION) return retcode;

        «ENDFOR»
        ''')
    }
    
    private def getInternalHandlerName(EventHandlerDeclaration handler) {
        '''Button«handler.sensorInstance.buttonName.toFirstUpper»_OnEvent'''
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