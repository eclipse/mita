package org.eclipse.mita.platform.xdk110.sensors

import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IComponentConfiguration
import com.google.inject.Inject

class GyroscopeSensorFusionGenerator extends AbstractSystemResourceGenerator {
    
    public static final String CONFIG_ITEM_POWER_MODE = 'power_mode';
    public static final String CONFIG_ITEM_STANDBY_TIME = 'standby_time';
    public static final String CONFIG_ITEM_TEMPERATURE_OVERSAMPLING = 'temperature_oversampling';
    public static final String CONFIG_ITEM_PRESSURE_OVERSAMPLING = 'pressure_oversampling';
    public static final String CONFIG_ITEM_HUMIDITY_OVERSAMPLING = 'humidity_oversampling';
    
    @Inject
    protected extension GeneratorUtils
    
    @Inject
	protected CodeFragmentProvider codeFragmentProvider
    
    override generateSetup() {
        codeFragmentProvider.create('''
        Retcode_T exception = RETCODE_OK;
        
        exception = CalibratedGyro_init(xdkCalibratedGyroscope_Handle);
        «generateExceptionHandler(component, 'exception')»
        ''')
        .addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
        .addHeader('BCDS_Retcode.h', true, IncludePath.HIGH_PRIORITY)
        .addHeader('XdkSensorHandle.h', true)
        .addHeader("BCDS_CalibratedGyro.h", true)
    }
            
    override generateEnable() {
        return CodeFragment.EMPTY;
    }
    
	override generateAccessPreparationFor(ModalityAccessPreparation accessPreparation) {
		val xyzData = accessPreparation.dataVariable;
		val accuracy = accessPreparation.accuracyVariable;
		val readsXYZ = accessPreparation.modalities.findFirst[it.name.endsWith("_axis")] !== null;
		val readsAcc = accessPreparation.modalities.findFirst[it.name == "accuracy"] !== null;
		return codeFragmentProvider.create('''
		«IF readsXYZ»
		CalibratedGyro_XyzDpsData_T «xyzData»;
		exception = CalibratedGyro_readXyzDpsValue(&«xyzData»);
		«generateExceptionHandler(component, 'exception')»
        «ENDIF»

        ««« Until we can actually use platform defined enums in user code we use an uint8_t here
        «IF readsAcc» 
        uint8_t «accuracy»;
        exception = CalibratedAccel_getStatus((uint8_t*) &«accuracy»);
        «generateExceptionHandler(component, 'exception')»
        «ENDIF»
        ''')
        .addHeader('BCDS_Gyroscope.h', true)
        .addHeader('XdkSensorHandle.h', true)
    }
	
	def String getDataVariable(ModalityAccessPreparation preparation) {
		return preparation.uniqueIdentifier.toFirstLower + "_data";
	}
    def String getAccuracyVariable(ModalityAccessPreparation preparation) {
		return preparation.uniqueIdentifier.toFirstLower + "_accuracy";
    }
    
	override generateModalityAccessFor(ModalityAccess modalityAccess) {
		val xyzData = modalityAccess.preparation.dataVariable;
		val accuracy = modalityAccess.preparation.accuracyVariable;
		val modalityName = modalityAccess.modality.name;
        
        return switch(modalityName) {
            case 'x_axis': codeFragmentProvider.create('''«xyzData».xAxisData''')
            case 'y_axis': codeFragmentProvider.create('''«xyzData».yAxisData''')
            case 'z_axis': codeFragmentProvider.create('''«xyzData».zAxisData''')
            case 'accuracy': codeFragmentProvider.create('''«accuracy»''')
        }
    }
    
    
}
