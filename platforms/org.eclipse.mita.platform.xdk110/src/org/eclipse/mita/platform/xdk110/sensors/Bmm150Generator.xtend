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
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IComponentConfiguration
import org.eclipse.mita.program.generator.IPlatformExceptionGenerator

class Bmm150Generator extends AbstractSystemResourceGenerator {
	
	@Inject
    protected extension GeneratorUtils
    
    @Inject
    protected IPlatformExceptionGenerator exceptionGenerator;
    
	override generateSetup() {
		return codeFragmentProvider.create('''
		«exceptionGenerator.exceptionType» exception = «exceptionGenerator.noExceptionStatement»;
		exception = Magnetometer_init(XdkMagnetometer_BMM150_Handle);
		«generateExceptionHandler(component, 'exception')»
		return Magnetometer_setPresetMode(XdkMagnetometer_BMM150_Handle, «configuration.getBmmPresetEnumValue»);
		''')
		.addHeader("BCDS_Magnetometer.h", true)
		.addHeader("XDK_SensorHandle.h", true)
	}
	
	override generateEnable() {
		return CodeFragment.EMPTY;
	}
	
	def String getBmmPresetEnumValue(IComponentConfiguration config) {
    	//remove BW_, add prefix
        '''MAGNETOMETER_BMM150_PRESETMODE_«config.getEnumerator('mode')?.name?.toUpperCase»'''
    }
    
    override generateAccessPreparationFor(ModalityAccessPreparation accessPreparation) {
		return codeFragmentProvider.create('''
        Magnetometer_XyzData_T «accessPreparation.dataVariable»;
        exception = Magnetometer_readXyzLsbData(XdkMagnetometer_BMM150_Handle, &«accessPreparation.dataVariable»);
        «generateExceptionHandler(component, 'exception')»
        ''')
        .addHeader('BCDS_Magnetometer.h', true)
        .addHeader('XdkSensorHandle.h', true)
    }
    
    def String getDataVariable(ModalityAccessPreparation preparation) {
		return preparation.uniqueIdentifier.toFirstLower;
	}
    
    override generateModalityAccessFor(ModalityAccess modalityAccess) {
		val dataVariable = modalityAccess.preparation.dataVariable;
		val modalityName = modalityAccess.modality.name;
        
        return switch(modalityName) {
            case 'x_axis': codeFragmentProvider.create('''«dataVariable».xAxisData''')
            case 'y_axis': codeFragmentProvider.create('''«dataVariable».yAxisData''')
            case 'z_axis': codeFragmentProvider.create('''«dataVariable».zAxisData''')
            case 'resistance': codeFragmentProvider.create('''«dataVariable».resistance''')
        }
    }
}
