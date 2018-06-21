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
import org.eclipse.mita.platform.SystemResourceEvent
import org.eclipse.mita.platform.xdk110.platform.EventLoopGenerator
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
import com.google.inject.Inject

class Bma280Generator extends AbstractSystemResourceGenerator {

	@Inject
	protected extension GeneratorUtils
	
	@Inject
	protected EventLoopGenerator eventLoopGenerator
	
    override generateSetup() {
        codeFragmentProvider.create('''
        Retcode_T retcode = RETCODE_OK;

        /* Extract BMA280 Handle from Advanced API */
        Bma280Utils_InfoPtr_T bma280UtilityCfg = xdkAccelerometers_BMA280_Handle->SensorPtr;

        /* Register Callback */
        bma280UtilityCfg->ISRCallback = BMA280_IsrCallback;

        retcode = Bma280Utils_initialize(bma280UtilityCfg);
        if(retcode != RETCODE_OK)
        {
            return retcode;
        }
        
        /* Do soft reset and wait 2-3 ms */
        // bma2x2_soft_rst();
        /* Overwrite settings */
        
        /* Block One: Basic Settings */
        /* Required: Set power mode to normal for configuration */
        bma2x2_set_power_mode(BMA2x2_MODE_NORMAL);
        
        /* Set Bandwidth */
        bma2x2_set_bw(«configuration.getBmaEnumValue('bandwidth')»);
        
        /* Setting to filtered low-bandwidth */
        bma2x2_set_high_bw(1);
        
        /* Set Range */
        bma2x2_set_range(«configuration.getBmaEnumValue('range')»);
        
        /* Set Sleep Duration */
        //bma2x2_set_sleep_durn(BMA2x2_SLEEP_DURN_1S);
        //bma2x2_set_sleep_timer_mode(0);
        /* Set Interrupt latch and level */
        
        /* Output stages */
        bma2x2_set_latch_intr(BMA2x2_LATCH_DURN_250MS);
        bma2x2_set_intr_level(BMA2x2_INTR1_LEVEL, ACTIVE_LOW);
        bma2x2_set_intr_level(BMA2x2_INTR2_LEVEL, ACTIVE_LOW);
        bma2x2_set_intr_output_type(BMA2x2_INTR1_OUTPUT, PUSS_PULL);
        bma2x2_set_intr_output_type(BMA2x2_INTR2_OUTPUT, PUSS_PULL);

        /* Set power mode to target value */
        bma2x2_set_power_mode(BMA2x2_MODE_NORMAL);
        
        /* Group 1: INTR1 Settings */
        bma2x2_set_intr_low_g(BMA2x2_INTR1_LOW_G, INTR_ENABLE);
        bma2x2_set_intr_high_g(BMA2x2_INTR1_HIGH_G, INTR_ENABLE);
        bma2x2_set_intr_slope(BMA2x2_INTR1_SLOPE, INTR_ENABLE);
        bma2x2_set_intr_slow_no_motion(BMA2x2_INTR1_SLOW_NO_MOTION, INTR_ENABLE);
        bma2x2_set_intr_double_tap(BMA2x2_INTR1_DOUBLE_TAP, INTR_ENABLE);
        bma2x2_set_intr_single_tap(BMA2x2_INTR1_SINGLE_TAP, INTR_ENABLE);
        bma2x2_set_intr_orient(BMA2x2_INTR1_ORIENT, INTR_ENABLE);
        bma2x2_set_intr_flat(BMA2x2_INTR1_FLAT, INTR_ENABLE);
        bma2x2_set_new_data(BMA2x2_INTR1_NEWDATA, INTR_ENABLE);
        bma2x2_set_intr1_fifo_wm(INTR_ENABLE);
        bma2x2_set_intr1_fifo_full(INTR_ENABLE);
        
        /* Group 2: INTR2 Settings */
        bma2x2_set_intr_low_g(BMA2x2_INTR2_LOW_G, INTR_DISABLE);
        bma2x2_set_intr_high_g(BMA2x2_INTR2_HIGH_G, INTR_DISABLE);
        bma2x2_set_intr_slope(BMA2x2_INTR2_SLOPE, INTR_DISABLE);
        bma2x2_set_intr_slow_no_motion(BMA2x2_INTR2_SLOW_NO_MOTION, INTR_DISABLE);
        bma2x2_set_intr_double_tap(BMA2x2_INTR2_DOUBLE_TAP, INTR_DISABLE);
        bma2x2_set_intr_single_tap(BMA2x2_INTR2_SINGLE_TAP, INTR_DISABLE);
        bma2x2_set_intr_orient(BMA2x2_INTR2_ORIENT, INTR_DISABLE);
        bma2x2_set_intr_flat(BMA2x2_INTR2_FLAT, INTR_DISABLE);
        bma2x2_set_new_data(BMA2x2_INTR2_NEWDATA, INTR_DISABLE);
        bma2x2_set_intr2_fifo_wm(INTR_DISABLE);
        bma2x2_set_intr2_fifo_full(INTR_DISABLE);
        
        «IF eventHandler.containsHandlerFor('log_g')»
        /* low-g  */
        bma2x2_set_thres(BMA2x2_LOW_THRES, BMA2x2_LOW_THRES_IN_G(0.4, 2.0));
        bma2x2_set_durn( BMA2x2_LOW_DURN, 10);
        bma2x2_set_low_high_g_hyst(BMA2x2_LOW_G_HYST, BMA2x2_LOW_HYST_IN_G(0.1, 2.0));
        bma2x2_set_low_g_mode(LOW_G_SUMMING_MODE);
        bma2x2_set_source(BMA2x2_SOURCE_LOW_G, 0); /* Data source for interrupt engine */
        «ENDIF»
        
        «IF eventHandler.containsHandlerFor('high_g')»
        /* high-g  */
        bma2x2_set_thres(BMA2x2_HIGH_THRES, BMA2x2_HIGH_THRES_IN_G(1.5, 2.0));
        bma2x2_set_durn( BMA2x2_HIGH_DURN, 10);
        bma2x2_set_low_high_g_hyst(BMA2x2_HIGH_G_HYST, BMA2x2_HIGH_HYST_IN_G(0.5, 2.0));
        bma2x2_set_source(BMA2x2_SOURCE_HIGH_G, 0); /* Data source for interrupt engine */
        «ENDIF»
        
        «IF eventHandler.containsHandlerFor('any_motion')»
        /* any motion */
        bma2x2_set_thres(BMA2x2_SLOPE_THRES, «configuration.getInteger('any_motion_threshold')»);
        bma2x2_set_durn(BMA2x2_SLOPE_DURN, 0);
        bma2x2_set_source(BMA2x2_SOURCE_SLOPE, 0); /* Data source for interrupt engine */
        «ENDIF»
        
        «IF eventHandler.containsHandlerFor('no_motion')»
        /* no motion */
        bma2x2_set_thres(BMA2x2_SLOW_NO_MOTION_THRES, «configuration.getInteger('no_motion_threshold')»);
        bma2x2_set_durn(BMA2x2_SLOW_NO_MOTION_DURN, 1);
        bma2x2_set_slow_no_motion(BMA2x2_SLOW_NO_MOTION_ENABLE_X, INTR_ENABLE);
        bma2x2_set_slow_no_motion(BMA2x2_SLOW_NO_MOTION_ENABLE_Y, INTR_ENABLE);
        bma2x2_set_slow_no_motion(BMA2x2_SLOW_NO_MOTION_ENABLE_Z, INTR_ENABLE);
        bma2x2_set_slow_no_motion(BMA2x2_SLOW_NO_MOTION_ENABLE_SELECT, INTR_ENABLE);
        «ENDIF»
        
        «IF eventHandler.containsHandlerFor('single_tap') || eventHandler.containsHandlerFor('double_tap')»
        /* single-tap double-tap */
        bma2x2_set_tap_durn(TAP_DURN_250_MS);
        bma2x2_set_tap_quiet(TAP_QUIET_30_MS);
        bma2x2_set_tap_thres((1.25 * 32 / 2.0)); //1250mg
        bma2x2_set_tap_shock(TAP_SHOCK_50_MS);
        bma2x2_set_source(BMA2x2_SOURCE_TAP, 0);
        //bma2x2_set_tap_sample( 0x02 );
        «ENDIF»
        
        /* orientation */
        
        /* flat */
        
        /* New data */
        bma2x2_set_source(BMA2x2_SOURCE_DATA, 0);
        ''')
        .setPreamble('''

«««        «FOR eventHandler : eventHandler»
«««        «val basename = GeneratorUtils.getBaseName((eventHandler.event as SystemEventSource).source).toUpperCase»
«««        #define «basename»_CODE UINT32_C(«basename.hashCode»)
«««        «ENDFOR»
        
        /* BMA280 ISR Callback */
        static void BMA280_IsrCallback(uint32_t channel, uint32_t edge);
        «IF !eventHandler.empty»
        
        /* BMA280 Event Resolver */
        static Retcode_T BMA280_Event(void * param1, uint32_t param2);
        «ENDIF»
        
        static void BMA280_IsrCallback(uint32_t channel, uint32_t edge)
        {
            BCDS_UNUSED(channel);
            BCDS_UNUSED(edge);
            «IF !eventHandler.empty»

            /* Enqueue Event Resolver */
            «eventLoopGenerator.generateEventloopInject('BMA280_Event', 'NULL', '0')»
            «ENDIF»
        }
        
        «IF !eventHandler.empty»
        static Retcode_T BMA280_Event(void* param1, uint32_t param2)
        {
            (void) param1;
            (void) param2;
            
            /* Read from interrupt status information */
            uint8_t interruptSource[4];
            (void) bma2x2_get_intr_stat(interruptSource);
            
            /* Trigger the corresponding event depending on the ISR mask */
            «FOR eventHandler : eventHandler»
            «generateEventDispatch(eventHandler)»
            «ENDFOR»

            return RETCODE_OK;
        }
        «ENDIF»

        ''')
        .addHeader('BCDS_Basics.h', true, IncludePath.ULTRA_HIGH_PRIORITY)
        .addHeader('BCDS_CmdProcessor.h',true)
        .addHeader('XdkSensorHandle.h', true)
        .addHeader('bma2x2.h', true)
        .addHeader('BCDS_Bma280Utils.h', true)        
        .addHeader('MitaEvents.h', false);
    }
    
    def String getBmaEnumValue(IComponentConfiguration config, String configItemName) {
        '''BMA2x2_«config.getEnumerator(configItemName)?.name?.toUpperCase»'''
    }
    
    override generateEnable() {
        codeFragmentProvider.create('''
        /* Enable Active Sensor Events */
        «FOR handler : eventHandler»
        «enableInterrupt((handler.event as SystemEventSource).source as SystemResourceEvent)»
        «ENDFOR»
        
        ''');
    }
    
    def boolean containsHandlerFor(Iterable<EventHandlerDeclaration> handler, String name) {
        return handler.findFirst[x | (x.event as SystemEventSource).source.name == name ] !== null;
    }
    
	override generateAccessPreparationFor(ModalityAccessPreparation accessPreparation) {
		val uid = accessPreparation.hashCode;
		val dataVariable = accessPreparation.uniqueIdentifier.toFirstLower;
		
		return codeFragmentProvider.create('''
        struct bma2x2_accel_data «dataVariable»;
        exception = «component.readXyzName»(&«dataVariable»);
        «generateExceptionHandler(accessPreparation, 'exception')»
        ''')
        .addHeader('bma2x2.h', true)
        .addHeader('''«component.fileBasename».h''', false);
    }
    
	override generateModalityAccessFor(ModalityAccess access) {
		val dataVariable = access.preparation.uniqueIdentifier.toFirstLower
		val result = switch(access.modality.name) {
            case 'x_axis': codeFragmentProvider.create('''«dataVariable».x''')
            case 'y_axis': codeFragmentProvider.create('''«dataVariable».y''')
            case 'z_axis': codeFragmentProvider.create('''«dataVariable».z''')
            case 'magnitude':
                codeFragmentProvider.create('''(uint32_t)sqrt((«dataVariable».x * «dataVariable».x) + («dataVariable».y * «dataVariable».y) + («dataVariable».z * «dataVariable».z))''')
                .addHeader('math.h', true)
                .addHeader('BCDS_Basics.h', true)
            default: throw new UnsupportedOperationException('Unsupported modality ' + access.modality)
        };
        
        return result.addHeader('bma2x2.h', true);
    }

    override generateAdditionalHeaderContent() {
        codeFragmentProvider.create('''
        Retcode_T «component.readXyzName»(struct bma2x2_accel_data* result);
        ''')
        .addHeader('bma2x2.h', true);
    }
    
    override generateAdditionalImplementation() {
        codeFragmentProvider.create('''
        Retcode_T «component.readXyzName»(struct bma2x2_accel_data* result)
        {    
            // read sensor data
            BMA2x2_RETURN_FUNCTION_TYPE bmaReadRc = bma2x2_read_accel_xyz(result);
            if(bmaReadRc != 0)
            {
                return RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_FAILURE);
            }

            // remap to XDK axis alignment
            AxisRemap_Data_T axisRemapping = { INT32_C(0), INT32_C(0), INT32_C(0) };
            axisRemapping.x = result->x;
            axisRemapping.y = result->y;
            axisRemapping.z = result->z;
            Retcode_T remappingStatus = Bma280Utils_remapAxis((Bma280Utils_InfoPtr_T) xdkAccelerometers_BMA280_Handle->SensorPtr, &axisRemapping);
            
            // store in result
            if (RETCODE_OK == remappingStatus)
            {
                result->x = axisRemapping.x;
                result->y = axisRemapping.y;
                result->z = axisRemapping.z;
                return RETCODE_OK;
            } else {
                return remappingStatus;
            }
        }
        ''')
        .addHeader('bma2x2.h', true)
        .addHeader('BCDS_Bma280Utils.h', true);
    }
    
    private def getReadXyzName(AbstractSystemResource context)
    '''«context.baseName»_ReadXYZ'''

    
    private def CodeFragment generateEventDispatch(EventHandlerDeclaration handler) {
        val basename = handler.baseName.toUpperCase
        val eventName = '''«basename»_CODE'''
        
        var bitMaskAndstatusByte = switch basename {
            case 'ACCELEROMETERANY_MOTION': 'BMA2x2_SLOPE_INTR_STAT_MSK' -> 'BMA2x2_STAT1'
            case 'ACCELEROMETERNO_MOTION': 'BMA2x2_SLOW_NO_MOTION_INTR_STAT_MSK' -> 'BMA2x2_STAT1'
            case 'ACCELEROMETERLOW_G': 'BMA2x2_LOW_G_INTR_STAT_MSK' -> 'BMA2x2_STAT1'
            case 'ACCELEROMETERHIGH_G': 'BMA2x2_HIGH_G_INTR_STAT_MSK' -> 'BMA2x2_STAT1'
            case 'ACCELEROMETERSINGLE_TAP': 'BMA2x2_SINGLE_TAP_INTR_STAT_MSK' -> 'BMA2x2_STAT1'
            case 'ACCELEROMETERDOUBLE_TAP': 'BMA2x2_DOUBLE_TAP_INTR_STAT_MSK' -> 'BMA2x2_STAT1'
            case 'ACCELEROMETERFLAT': 'BMA2x2_FLAT_INTR_STAT_MSK' -> 'BMA2x2_STAT1'
            case 'ACCELEROMETERORIENTATION': 'BMA2x2_ORIENT_INTR_STAT_MSK' -> 'BMA2x2_STAT1'
            case 'ACCELEROMETERFIFO_FULL': 'BMA2x2_FIFO_FULL_INTR_STAT_MSK' -> 'BMA2x2_STAT2'
            case 'ACCELEROMETERFIFO_WML': 'BMA2x2_FIFO_WM_INTR_STAT_MSK' -> 'BMA2x2_STAT2'
            case 'ACCELEROMETERNEW_DATA': 'BMA2x2_DATA_INTR_STAT_MSK' -> 'BMA2x2_STAT2'
        }
    
        val bitMask = bitMaskAndstatusByte.key;
        val statusByte = bitMaskAndstatusByte.value;
        return codeFragmentProvider.create('''
        if(interruptSource[«statusByte»] & «bitMask»)
        {
            «eventLoopGenerator.generateEventloopInject(handler.handlerName, 'NULL', '0')»
        }
        ''')
    }
    
    private def String enableInterrupt(SystemResourceEvent event)
    {
        val activation = switch event.baseName.toUpperCase {
            case 'BMA280ANY_MOTION' :
            '''
            bma2x2_set_intr_enable(BMA2x2_SLOPE_X_INTR, INTR_DISABLE);
            bma2x2_set_intr_enable(BMA2x2_SLOPE_Y_INTR, INTR_DISABLE);
            bma2x2_set_intr_enable(BMA2x2_SLOPE_Z_INTR, INTR_DISABLE);
            '''    
            case 'BMA280NO_MOTION' :
            '''
            bma2x2_set_slow_no_motion(BMA2x2_SLOW_NO_MOTION_ENABLE_X, INTR_ENABLE);
            bma2x2_set_slow_no_motion(BMA2x2_SLOW_NO_MOTION_ENABLE_Y, INTR_ENABLE);
            bma2x2_set_slow_no_motion(BMA2x2_SLOW_NO_MOTION_ENABLE_Z, INTR_ENABLE);
            '''
            case 'BMA280LOW_G' :
            '''
            bma2x2_set_intr_enable(BMA2x2_LOW_G_INTR, INTR_ENABLE);
            '''        
            case 'BMA280HIGH_G' :
             '''
            bma2x2_set_intr_enable(BMA2x2_HIGH_G_X_INTR, INTR_ENABLE);
            bma2x2_set_intr_enable(BMA2x2_HIGH_G_Y_INTR, INTR_ENABLE);
            bma2x2_set_intr_enable(BMA2x2_HIGH_G_Z_INTR, INTR_ENABLE);
            '''
            case 'BMA280SINGLE_TAP' :
            '''
            bma2x2_set_intr_enable(BMA2x2_SINGLE_TAP_INTR, INTR_ENABLE);
            '''
            case 'BMA280DOUBLE_TAP' :
            '''
            bma2x2_set_intr_enable(BMA2x2_DOUBLE_TAP_INTR, INTR_ENABLE);
            '''
            case 'BMA280FLAT' :
            '''
            bma2x2_set_intr_enable(BMA2x2_FLAT_INTR, INTR_DISABLE);
            '''
            case 'BMA280ORIENTATION' :
            '''
            bma2x2_set_intr_enable(BMA2x2_ORIENT_INTR, INTR_DISABLE);
            '''
            case 'BMA280FIFO_FULL':
            '''
            bma2x2_set_intr_enable(BMA2x2_FIFO_FULL_INTR, INTR_DISABLE);
            '''
            case 'BMA280FIFO_WML' :
            '''
            bma2x2_set_intr_enable(BMA2x2_FIFO_WM_INTR, INTR_DISABLE);
            '''
            case 'BMA280NEW_DATA' :
            '''
            bma2x2_set_intr_enable(BMA2x2_FIFO_FULL_INTR, INTR_DISABLE);
            '''
        }
        
        return '''
        /* Activating «event.name» */
        «activation»
        
        '''
    }
    
}