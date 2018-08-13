package org.eclipse.mita.platform.xdk110.io

import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.generator.CodeFragment

class SDCardGenerator extends AbstractSystemResourceGenerator {
	
	override generateSetup() {
		codeFragmentProvider.create('''
		''')
		.addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
		.addHeader('BCDS_Retcode.h', true, IncludePath.VERY_HIGH_PRIORITY)
		.addHeader("FreeRTOS.h", true, IncludePath.HIGH_PRIORITY)
		.addHeader("task.h", true)
		.addHeader("string.h", true)
		.addHeader("XdkCommonInfo.h", true)
		.addHeader("ff.h", true)
		.addHeader("BCDS_SDCard_Driver.h", true)
		.setPreamble('''
		static FATFS StorageSDCardFatFSObject; /** File system specific objects */
		/**< Macro to define default logical drive */
		#define STORAGE_DEFAULT_LOGICAL_DRIVE           ""

		/**< Macro to define force mount */
		#define STORAGE_SDCARD_FORCE_MOUNT              UINT8_C(1)

		/**< SD Card Drive 0 location */
		#define STORAGE_SDCARD_DRIVE_NUMBER             UINT8_C(0)

		/**< File seek to the first location */
		#define STORAGE_SEEK_FIRST_LOCATION             UINT8_C(0)

		«FOR sigInst : setup.signalInstances»
		«IF sigInst.instanceOf.name.startsWith("persistentFile")»
		static uint32_t «sigInst.name»DataRead = 0UL;
		static uint32_t «sigInst.name»DataWrite = 0UL;
		«ENDIF»
		«ENDFOR»

		''')


	}
	
	def CodeFragment getSize(SignalInstance instance) {
		val result = StaticValueInferrer.infer(ModelUtils.getArgumentValue(instance, instance.sizeName), []);
		if(result instanceof Integer) {
			return codeFragmentProvider.create('''«result»''');
		}
		else {
			return codeFragmentProvider.create('''-1''');	
		}
		
	}
	
	static def String getSizeName(SignalInstance instance) {
		if(instance.instanceOf.name.startsWith("persistentFile")) {
			return "blockSize";
		} 
		else {
			return "fileSize";
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
		val data = sigInst.dataAccessor(valueVariableName);
		val len = sigInst.getSize;
		val filename = sigInst.filenameAccessor(valueVariableName);
		codeFragmentProvider.create('''
			Retcode_T retcode = RETCODE_OK;
			FRESULT sdCardReturn = FR_OK, fileOpenReturn = FR_OK;
			FILINFO sdCardFileInfo;
			#if _USE_LFN
			sdCardFileInfo.lfname = NULL;
			#endif
			FIL fileReadHandle;
			UINT bytesRead;
			uint32_t fileSeekIndex = 0UL;
			
			sdCardReturn = f_stat(«filename», &sdCardFileInfo);
			if (FR_OK == sdCardReturn)
			{
				fileOpenReturn = f_open(&fileReadHandle, «filename», FA_OPEN_EXISTING | FA_READ);
			}
			«IF sigInst.instanceOf.name.startsWith("persistentFile")»
			fileSeekIndex = «sigInst.name»DataRead;
			«ENDIF»
			if ((FR_OK == sdCardReturn) && (FR_OK == fileOpenReturn))
			{
			    sdCardReturn = f_lseek(&fileReadHandle, fileSeekIndex);
			}
			if(fileSeekIndex > sdCardFileInfo.fsize)
			{
				return EXCEPTION_ENDOFFILEEXCEPTION;
			}
			if ((FR_OK == sdCardReturn) && (FR_OK == fileOpenReturn))
			{
			    sdCardReturn = f_read(&fileReadHandle, «data», «len», &bytesRead); /* Read a chunk of source file */
			}
			if (FR_OK == fileOpenReturn)
			{
				«IF sigInst.instanceOf.name.startsWith("persistentFile")»
				«sigInst.name»DataRead += bytesRead;
				«ENDIF»
			    sdCardReturn = f_close(&fileReadHandle);
			}
			if ((FR_OK != sdCardReturn) || (FR_OK != fileOpenReturn))
			{
			    retcode = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_STORAGE_SDCARD_READ_FAILED);
			}
			return retcode;
		''')
	}
		
	override generateSignalInstanceSetter(SignalInstance sigInst, String valueVariableName) {
		val data = sigInst.dataAccessor(valueVariableName);
		val len = sigInst.lenAccessor(valueVariableName);
		val filename = sigInst.filenameAccessor(valueVariableName);
		
		codeFragmentProvider.create('''
			Retcode_T retcode = RETCODE_OK;
			uint32_t length = 0;
			FRESULT sdCardReturn = FR_OK, fileOpenReturn = FR_OK;
			FIL fileWriteHandle;
			UINT bytesWritten;
			uint32_t fileSeekIndex = 0UL;
			fileOpenReturn = f_open(&fileWriteHandle, «filename», FA_WRITE | FA_CREATE_ALWAYS);
			«IF sigInst.instanceOf.name.startsWith("persistentFile")»
			fileSeekIndex = «sigInst.name»DataWrite;
			«ENDIF»
			if ((FR_OK == sdCardReturn) && (FR_OK == fileOpenReturn))
			{
			    sdCardReturn = f_lseek(&fileWriteHandle, fileSeekIndex);
			}
			if ((FR_OK == sdCardReturn) && (FR_OK == fileOpenReturn))
			{
			    sdCardReturn = f_write(&fileWriteHandle, «data», «len», &bytesWritten); /* Write it to the destination file */
			}
			if (FR_OK == fileOpenReturn)
			{
				«IF sigInst.instanceOf.name.startsWith("persistentFile")»
				«sigInst.name»DataWrite += bytesWritten;
				«ENDIF»
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
		return if(sigInst.instanceOf.name.endsWith("Text")) {
			codeFragmentProvider.create('''*«varName»''');
		} 
		else {	
			codeFragmentProvider.create('''«varName»->data''');
		}
	}
		
	def CodeFragment lenAccessor(SignalInstance sigInst, String varName) {
		return if(sigInst.instanceOf.name.endsWith("Text")) {
			codeFragmentProvider.create('''strlen(*«varName»)''');
		} 
		else {	
			codeFragmentProvider.create('''«varName»->length''');
		}
	}

	def CodeFragment filenameAccessor(SignalInstance sigInst, String varName) {
		val filenameRaw = StaticValueInferrer.infer(ModelUtils.getArgumentValue(sigInst, 'filePath'), []);
		return  if(filenameRaw instanceof String) {
			codeFragmentProvider.create('''"«filenameRaw»"''');
		} 
		else {
			codeFragmentProvider.create('''INVALID_ARGUMENT''');
		}
	}	
}