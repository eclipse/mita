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

package org.eclipse.mita.platform.xdk110.io

import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.generator.CodeFragment

import com.google.inject.Inject
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator.LogLevel

class SDCardGenerator extends AbstractSystemResourceGenerator {

	@Inject(optional=true)
	protected IPlatformLoggingGenerator loggingGenerator

	override generateSetup() {
		codeFragmentProvider.create('''
		''').addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY).addHeader('BCDS_Retcode.h', true,
			IncludePath.VERY_HIGH_PRIORITY).addHeader("FreeRTOS.h", true, IncludePath.HIGH_PRIORITY).addHeader("task.h",
			true).addHeader("string.h", true).addHeader("XdkCommonInfo.h", true).addHeader("ff.h", true).addHeader(
			"BCDS_SDCard_Driver.h", true).setPreamble('''
			static FATFS StorageSDCardFatFSObject; /** File system specific objects */
			/**< Macro to define default logical drive */
			#define STORAGE_DEFAULT_LOGICAL_DRIVE           ""
			
			/**< Macro to define force mount */
			#define STORAGE_SDCARD_FORCE_MOUNT              UINT8_C(1)
			
			/**< SD Card Drive 0 location */
			#define STORAGE_SDCARD_DRIVE_NUMBER             UINT8_C(0)
			
			«FOR sigInst : setup.signalInstances»
				«IF sigInst.instanceOf.name.startsWith("resuming")»
					static uint32_t «sigInst.name»FilePosition = 0UL;
				«ENDIF»
			«ENDFOR»
			
		''')

	}

	def CodeFragment getSize(SignalInstance instance) {
		val result = StaticValueInferrer.infer(ModelUtils.getArgumentValue(instance, instance.sizeName), []);
		if (result instanceof Integer) {
			return codeFragmentProvider.create('''«result»''');
		} else {
			return codeFragmentProvider.create('''-1''');
		}

	}

	static def String getSizeName(SignalInstance instance) {
		if (instance.instanceOf.name.startsWith("rewinding")) {
			return "fileSize";
		} else {
			return "blockSize";
		}
	}

	override generateEnable() {
		codeFragmentProvider.create('''
			Retcode_T retcode = RETCODE_OK;
			retcode = SDCardDriver_Initialize();
			if (RETCODE_OK == retcode)
			{
				if (SDCARD_INSERTED != SDCardDriver_GetDetectStatus())
				{
					«loggingGenerator.generateLogStatement(LogLevel.Error, "SD card was not detected for Storage")»
					retcode = RETCODE(RETCODE_SEVERITY_WARNING, RETCODE_STORAGE_SDCARD_NOT_AVAILABLE);
				}
			}
			if (RETCODE_OK == retcode)
			{
				retcode = SDCardDriver_DiskInitialize(STORAGE_SDCARD_DRIVE_NUMBER); /* Initialize SD card */
			}
			if (RETCODE_OK == retcode)
			{
				/* Initialize file system */
				if (FR_OK != f_mount(&StorageSDCardFatFSObject, STORAGE_DEFAULT_LOGICAL_DRIVE, STORAGE_SDCARD_FORCE_MOUNT))
				{
					retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_STORAGE_SDCARD_MOUNT_FAILED);
				}
			}
			return retcode;
		''')
	}

	override generateSignalInstanceGetter(SignalInstance sigInst, String valueVariableName) {
		val signalName = sigInst.instanceOf.name;
		if(signalName.endsWith("Write")) {
			return codeFragmentProvider.create('''
				BCDS_UNUSED(«valueVariableName»);
				return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
			''')
		} 
		val data = sigInst.dataAccessor(valueVariableName);
		val len = sigInst.getSize;
		val filename = sigInst.filenameAccessor(valueVariableName);
		val fileSeekIndex = if (signalName.startsWith("resuming")) {
				codeFragmentProvider.create('''«sigInst.name»FilePosition''');
			} else {
				codeFragmentProvider.create('''0''');
			}
		codeFragmentProvider.create('''
			Retcode_T retcode = RETCODE_OK;
			FRESULT sdCardReturn = FR_OK, fileOpenReturn = FR_OK;
			FILINFO sdCardFileInfo;
			#if _USE_LFN
			sdCardFileInfo.lfname = NULL;
			#endif
			FIL fileReadHandle;
			UINT bytesRead;
			
			sdCardReturn = f_stat(«filename», &sdCardFileInfo);
			if (FR_OK == sdCardReturn)
			{
				if(«fileSeekIndex» >= sdCardFileInfo.fsize)
				{
					return EXCEPTION_ENDOFFILEEXCEPTION;
				}
				else
				{
					fileOpenReturn = f_open(&fileReadHandle, «filename», FA_OPEN_EXISTING | FA_READ);
				}
			}
			if ((FR_OK == sdCardReturn) && (FR_OK == fileOpenReturn))
			{
			    sdCardReturn = f_lseek(&fileReadHandle, «fileSeekIndex»);
			}
			if ((FR_OK == sdCardReturn) && (FR_OK == fileOpenReturn))
			{
			    sdCardReturn = f_read(&fileReadHandle, «data», «len», &bytesRead); /* Read a chunk of source file */
			}
			if ((FR_OK == sdCardReturn) && (FR_OK == fileOpenReturn))
			{
				«IF signalName.startsWith("resuming")»
					«sigInst.name»FilePosition += bytesRead;
				«ENDIF»
			}
			if (FR_OK == fileOpenReturn)
			{
				sdCardReturn = f_close(&fileReadHandle);
			}
			if ((FR_OK != sdCardReturn) || (FR_OK != fileOpenReturn))
			{
			    retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_STORAGE_SDCARD_READ_FAILED);
			}
			return retcode;
		''')
		.addHeader("MitaExceptions.h", false)
	}

	override generateSignalInstanceSetter(SignalInstance sigInst, String valueVariableName) {
		val signalName = sigInst.instanceOf.name;
		val isAppending = signalName.startsWith("appending");
		if(signalName.endsWith("Read")) {
			return codeFragmentProvider.create('''
				BCDS_UNUSED(«valueVariableName»);
				return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
			''')
		} 
		
		val data = sigInst.dataAccessor(valueVariableName);
		val len = sigInst.lenAccessor(valueVariableName);
		val filename = sigInst.filenameAccessor(valueVariableName);
		val fileSeekIndex = if (isAppending) {
				codeFragmentProvider.create('''«sigInst.name»FilePosition''');
			} else {
				codeFragmentProvider.create('''0''');
			}
		val fileOpenMode = if (isAppending) {
			"FA_WRITE | FA_OPEN_ALWAYS"
		}
		else {
			"FA_WRITE | FA_CREATE_ALWAYS"
		}

		codeFragmentProvider.create('''
			Retcode_T retcode = RETCODE_OK;
			FRESULT sdCardReturn = FR_OK, fileOpenReturn = FR_OK;
			FIL fileWriteHandle;
			UINT bytesWritten;
			«IF isAppending»
			FILINFO sdCardFileInfo;
			#if _USE_LFN
			sdCardFileInfo.lfname = NULL;
			#endif
			uint32_t «fileSeekIndex»;
			«ENDIF»
			fileOpenReturn = f_open(&fileWriteHandle, «filename», «fileOpenMode»);
			«IF isAppending»
			if ((FR_OK == sdCardReturn) && (FR_OK == fileOpenReturn))
			{
				sdCardReturn = f_stat(«filename», &sdCardFileInfo);
				«fileSeekIndex» = sdCardFileInfo.fsize;
			}
			«ENDIF»
			if ((FR_OK == sdCardReturn) && (FR_OK == fileOpenReturn))
			{
			    sdCardReturn = f_lseek(&fileWriteHandle, «fileSeekIndex»);
			}
			if ((FR_OK == sdCardReturn) && (FR_OK == fileOpenReturn))
			{
			    sdCardReturn = f_write(&fileWriteHandle, «data», «len», &bytesWritten); /* Write it to the destination file */
			}
			if (FR_OK == fileOpenReturn)
			{
				sdCardReturn = f_close(&fileWriteHandle);
			}
			if ((FR_OK != sdCardReturn) || (FR_OK != fileOpenReturn))
			{
			    retcode = RETCODE(RETCODE_SEVERITY_WARNING, RETCODE_STORAGE_ERROR_IN_FILE_WRITE);
			}
			return retcode;
		''')
	}

	def CodeFragment dataAccessor(SignalInstance sigInst, String varName) {
		return codeFragmentProvider.create('''«varName»->data''');
	}

	def CodeFragment lenAccessor(SignalInstance sigInst, String varName) {
		return codeFragmentProvider.create('''«varName»->length''');
	}

	def CodeFragment filenameAccessor(SignalInstance sigInst, String varName) {
		val filenameRaw = StaticValueInferrer.infer(ModelUtils.getArgumentValue(sigInst, 'filePath'), []);
		return if (filenameRaw instanceof String) {
			codeFragmentProvider.create('''"«filenameRaw»"''');
		} else {
			codeFragmentProvider.create('''INVALID_ARGUMENT''');
		}
	}
}
