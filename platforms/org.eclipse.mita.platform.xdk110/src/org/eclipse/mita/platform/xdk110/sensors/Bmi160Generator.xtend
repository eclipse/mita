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

class Bmi160Generator extends AbstractSystemResourceGenerator {
    
    public static final String CONFIG_ITEM_POWER_MODE = 'power_mode';
    public static final String CONFIG_ITEM_STANDBY_TIME = 'standby_time';
    public static final String CONFIG_ITEM_TEMPERATURE_OVERSAMPLING = 'temperature_oversampling';
    public static final String CONFIG_ITEM_PRESSURE_OVERSAMPLING = 'pressure_oversampling';
    public static final String CONFIG_ITEM_HUMIDITY_OVERSAMPLING = 'humidity_oversampling';
    
    @Inject
    protected extension GeneratorUtils
    
    override generateSetup() {
        codeFragmentProvider.create('''
        Retcode_T exception = RETCODE_OK;
        
        exception = Gyroscope_init(xdkGyroscope_BMI160_Handle);
        «generateExceptionHandler(component, 'exception')»
        
        /* Set Bandwidth */
        exception = Gyroscope_setBandwidth(xdkGyroscope_BMI160_Handle, «configuration.getBmiBandwidthEnumValue»);
        «generateExceptionHandler(component, 'exception')»
        
        /* Set Powermode */
        exception = Gyroscope_setMode(xdkGyroscope_BMI160_Handle, GYROSCOPE_BMI160_POWERMODE_NORMAL);
        «generateExceptionHandler(component, 'exception')»
        

        /* Set Range */
        exception = Gyroscope_setRange(xdkGyroscope_BMI160_Handle, «configuration.getBmiRangeEnumValue»);
        «generateExceptionHandler(component, 'exception')»
        ''')
        .addHeader('BCDS_Basics.h', true, IncludePath.VERY_HIGH_PRIORITY)
        .addHeader('BCDS_Retcode.h', true, IncludePath.HIGH_PRIORITY)
        .addHeader('XdkSensorHandle.h', true)
        .addHeader("BCDS_Gyroscope.h", true)
    }
    
    def String getBmiBandwidthEnumValue(IComponentConfiguration config) {
    	//remove "BW_", add prefix
        '''GYROSCOPE_BMI160_BANDWIDTH_«config.getEnumerator('bandwidth')?.name?.toUpperCase?.substring(3)»'''
    }
    def String getBmiRangeEnumValue(IComponentConfiguration config) {
    	//add prefix and suffix, remove "Range_"
        '''GYROSCOPE_BMI160_«config.getEnumerator('range')?.name?.toUpperCase?.substring(6)»_RANGE'''
    }
    
        
    override generateEnable() {
        return CodeFragment.EMPTY;
    }
    
	override generateAccessPreparationFor(ModalityAccessPreparation accessPreparation) {
		return codeFragmentProvider.create('''
        Gyroscope_XyzData_T «accessPreparation.dataVariable»;
        exception = Gyroscope_readXyzValue(xdkGyroscope_BMI160_Handle, &«accessPreparation.dataVariable»);
        «generateExceptionHandler(component, 'exception')»
        ''')
        .addHeader('BCDS_Gyroscope.h', true)
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
        }
    }
    
    
}
