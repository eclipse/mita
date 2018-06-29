package org.eclipse.mita.platform.arduino.uno.sensors

import com.google.inject.Inject
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.SystemEventSource
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.GeneratorUtils

class ButtonGenerator extends AbstractSystemResourceGenerator {

	@Inject
	protected CodeFragmentProvider codeFragmentProvider

	@Inject
	protected extension GeneratorUtils

	override generateSetup() {
		codeFragmentProvider.create('''
			return Button_Connect();
		''').setPreamble('''
			«FOR handler : eventHandler»
				bool get«handler.handlerName»_flag(){
					return «handler.handlerName»_flag;
				}
				
				void set«handler.handlerName»_flag(bool val){
					«handler.handlerName»_flag = val;
				}
			«ENDFOR»
		''')
		.addHeader("Button.h", false)
		.addHeader("MitaEvents.h", false)
	}

	override generateEnable() {
		codeFragmentProvider.create('''
			Retcode_T retcode = NO_EXCEPTION;
			
			«FOR handler : eventHandler»
				retcode = Button_Enable((uint32_t) BUTTON_«handler.sensorInstance.buttonNumber», set«handler.handlerName»_flag, «IF handler.baseName.contains("Pressed")»true«ELSE»false«ENDIF»);
				if(retcode != NO_EXCEPTION) return retcode;
				
			«ENDFOR»
		''')
	}

	private def getSensorInstance(EventHandlerDeclaration declaration) {
		val event = declaration.event as SystemEventSource;
		return event.origin as AbstractSystemResource;
	}

	private def getButtonName(AbstractSystemResource origin) {
		return origin.name.split('_').last;
	}

	private def int getButtonNumber(AbstractSystemResource declaration) {
		return if (declaration.buttonName === 'one') {
			1
		} else {
			2
		}
	}
}
