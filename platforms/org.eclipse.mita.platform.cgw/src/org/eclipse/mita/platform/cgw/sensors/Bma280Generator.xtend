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

package org.eclipse.mita.platform.cgw.sensors

import com.google.inject.Inject
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.SystemResourceEvent
import org.eclipse.mita.platform.cgw.platform.EventLoopGenerator
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.SystemEventSource
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IComponentConfiguration

class Bma280Generator extends AbstractSystemResourceGenerator {

	@Inject
	protected extension GeneratorUtils

	@Inject
	protected CodeFragmentProvider codeFragmentProvider

	override generateSetup() {
		codeFragmentProvider.create('''
			Retcode_T exception = NO_EXCEPTION;
			exception = BSP_BMA280_Connect(COMMONGATEWAY_BMA280_ID);
			«generateExceptionHandler(null, "exception")»
			return exception;
		''').setPreamble('''
			s8 bma280_Write(u8 address, u8 reg, u8 * data, u8 len)
			{
			    Retcode_T retcode = I2CTransceiver_Write(&i2cTransceiverStruct, address, reg, data, len);
			    if (RETCODE_OK == retcode)
			    {
			        return SUCCESS;
			    }
			    else
			    {
			        return ERROR;
			    }
			}
			
			s8 bma280_Read(u8 address, u8 reg, u8 * data, u8 len)
			{
			    Retcode_T retcode = I2CTransceiver_Read(&i2cTransceiverStruct, address, reg, data, len);
			    if (RETCODE_OK == retcode)
			    {
			        return SUCCESS;
			    }
			    else
			    {
			        return ERROR;
			    }
			}
			struct bma2x2_t bma280Struct = {
			        .bus_read = bma280_Read,
			        .bus_write = bma280_Write,
			        .delay_msec = BSP_Board_Delay,
			        .dev_addr = COMMONGATEWAY_BMA280_I2CADDRESS,
			};
		''')
		.addHeader("BSP_CommonGateway.h", false)
		.addHeader("BCDS_BSP_BMA280.h", false)
		.addHeader("BCDS_MCU_I2C.h", false)
		.addHeader("BCDS_I2CTransceiver.h",	false)
		.addHeader("bma2x2.h", false)
		.addHeader("BCDS_BSP_Board.h", false)
		.addHeader("PlatformCGW.h", false)
	}

	override generateAdditionalHeaderContent() {
		return codeFragmentProvider.create('''
			«super.generateAdditionalHeaderContent()»
			
			Retcode_T SensorAccelerometer_readXyz(vec3d_16_t* data);
		''').addHeader("cgwTypes.h", false);
	}

	override generateEnable() {
		return codeFragmentProvider.create('''
			Retcode_T exception = NO_EXCEPTION;
			exception = BSP_BMA280_Enable(COMMONGATEWAY_BMA280_ID);
			«generateExceptionHandler(null, "exception")»
			if (SUCCESS != bma2x2_init(&bma280Struct))
			{
				exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
			}
			«generateExceptionHandler(null, "exception")»
			if (SUCCESS != bma2x2_set_bw(BMA2x2_«configuration.getEnumerator("bandwidth").toString.toUpperCase»))
			{
				exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
			}
			«generateExceptionHandler(null, "exception")»
			if (SUCCESS != bma2x2_set_range(BMA2x2_«configuration.getEnumerator("range").toString.toUpperCase»))
			{
				exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
			}
			BSP_Board_Delay(100);
			«generateExceptionHandler(null, "exception")»
			return exception;
		''')
		.setPreamble('''
			Retcode_T SensorAccelerometer_readXyz(vec3d_16_t* data) {
				struct bma2x2_accel_data bmaData;
				if(0 != bma2x2_read_accel_xyz(&bmaData)) {
					return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
				}
				data->x = bmaData.x;
				data->y = bmaData.y;
				data->z = bmaData.z;
				return RETCODE_OK;
			}
		''').addHeader("cgwTypes.h", false);
	}

	override generateAccessPreparationFor(ModalityAccessPreparation accessPreparation) {
		val modalityAccessPrepVarName = accessPreparation.uniqueIdentifier;
		return codeFragmentProvider.create('''
			vec3d_16_t «modalityAccessPrepVarName»;
			exception = SensorAccelerometer_readXyz(&«modalityAccessPrepVarName»);
			«generateExceptionHandler(accessPreparation, "exception")»
		''').addHeader("cgwTypes.h", false);
	}

	override generateModalityAccessFor(ModalityAccess modality) {
		val modalityAccessPrepVarName = modality.preparation.uniqueIdentifier;
		val modName = modality.modality.name;
		if(modName == "magnitude") {
			return codeFragmentProvider.create('''
				sqrt(«modalityAccessPrepVarName».x*«modalityAccessPrepVarName».x + 
					 «modalityAccessPrepVarName».y*«modalityAccessPrepVarName».y + 
					 «modalityAccessPrepVarName».z*«modalityAccessPrepVarName».z)
			''')	
		}
		else {
			return codeFragmentProvider.create('''«modalityAccessPrepVarName».«modName.substring(0, 1)»''');
		}
	}

}
