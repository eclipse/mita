package org.eclipse.mita.platform.xdk110.buses

import com.google.inject.Inject
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import org.eclipse.mita.base.types.EnumerationType

class UartGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	protected extension GeneratorUtils;
	@Inject
	protected extension StatementGenerator;
	
	def String cname(Enumerator e) {
		val etype = e.eContainer.castOrNull(EnumerationType);
		if(etype === null) {
			return "BAD MODEL";
		}
		val dict = #{
			"UartParity" -> [String s | s.toUpperCase.substring(0, s.length - "Parity".length) + "_PARITY"],
			"UartStopbits" -> [String s | "STOPBITS_" + s.toUpperCase]
		}
		
		return "BSP_EXTENSIONPORT_UART_" + (dict.get(etype.name)?.apply(e.name) ?: ("BAD CONFIG ITEM: " + e.name))
	}
	
	override generateSetup() {
		val baudrate = StaticValueInferrer.infer(setup.getConfigurationItemValue("baudrate"), []).castOrNull(Integer); 
		val parity =   StaticValueInferrer.infer(setup.getConfigurationItemValue("parity")  , []).castOrNull(Enumerator); 
		val stopbits = StaticValueInferrer.infer(setup.getConfigurationItemValue("stopbits"), []).castOrNull(Enumerator); 
		
		if(baudrate === null || parity === null || stopbits === null) {
			return codeFragmentProvider.create('''
				ERROR: INVALID SETUP: «#["baudrate" -> baudrate, "parity" -> parity, "stopbits" -> stopbits].filter[it.value === null].map[it.key].join(", ")»
			''');
		}
		
		return codeFragmentProvider.create('''
			Retcode_T exception = RETCODE_OK;
			
			exception = BSP_ExtensionPort_Connect();
			«generateLoggingExceptionHandler("Extension Port", "connect")»
			
			//GPIO_DriveModeSet(gpioPortB, gpioDriveModeHigh);
			exception = BSP_ExtensionPort_ConnectUart();
			«generateLoggingExceptionHandler("Uart", "connect")»
			
			uartHandle = BSP_ExtensionPort_GetUartHandle();
			if(uartHandle == NULL) {
				exception = RETCODE(RETCODE_SEVERITY_ERROR, RETCODE_NULL_POINTER);
			}
			«generateLoggingExceptionHandler("", "get Uart handle")»
			exception = MCU_UART_Initialize(uartHandle, UartDriverCallBack);
			«generateLoggingExceptionHandler("Uart", "initialize")»
			
			exception = BSP_ExtensionPort_SetUartConfig(BSP_EXTENSIONPORT_UART_BAUDRATE, «baudrate», NULL);
			«generateLoggingExceptionHandler("Uart baudrate", "set")»
			exception = BSP_ExtensionPort_SetUartConfig(BSP_EXTENSIONPORT_UART_PARITY,   «parity.cname», NULL);
			«generateLoggingExceptionHandler("Uart parity", "set")»
			exception = BSP_ExtensionPort_SetUartConfig(BSP_EXTENSIONPORT_UART_STOPBITS, «stopbits.cname», NULL);
			«generateLoggingExceptionHandler("Uart stopbits", "set")»
			
			return exception;
		''')
		.setPreamble('''
			HWHandle_T uartHandle;
			static uint8_t extensionBuf[300];
			static UARTTransceiver_T extension;
			
			bool checkForEOL(uint8_t c) {
				return true;
			}
			
			void UartDriverCallBack(UART_T uart, struct MCU_UART_Event_S event) {
				UARTTransceiver_LoopCallback(&extension, event);
			}
		''')
		.addHeader("BCDS_UARTTransceiver.h", false)
		.addHeader("BCDS_BSP_Board.h", false)
		.addHeader("BSP_ExtensionPort.h", false)
		.addHeader("BCDS_MCU_UART.h", false)
	}
	
	override generateEnable() {
		return codeFragmentProvider.create('''
			Retcode_T exception = RETCODE_OK;
			
			exception = BSP_ExtensionPort_EnableUart();
			«generateLoggingExceptionHandler("Uart", "enable")»
			
			exception = UARTTransceiver_Initialize(&extension, uartHandle, extensionBuf, sizeof(extensionBuf) - 1, UART_TRANSCEIVER_UART_TYPE_UART);
			«generateLoggingExceptionHandler("Uart Transceiver", "initialize")»
			
			exception = UARTTransceiver_Start(&extension, checkForEOL);
			«generateLoggingExceptionHandler("Uart Transceiver", "start")»
			
			return exception;
		''')
	}

	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		return codeFragmentProvider.create('''
			Retcode_T exception = RETCODE_OK;
			
			uint32_t readBytes = 0;
			exception = UARTTransceiver_ReadData(&extension, *«resultName», «ModelUtils.getArgumentValue(signalInstance, "length").code», &readBytes, 100);
			
			return exception;
		''')
	}
	
	override generateSignalInstanceSetter(SignalInstance signalInstance, String valueVariableName) {
		return codeFragmentProvider.create('''
			Retcode_T exception = RETCODE_OK;
			
			exception = UARTTransceiver_WriteData(&extension, *«valueVariableName», strlen(*«valueVariableName»), 100);
			
			return exception;
		''')
	}
	
}