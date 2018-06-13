package org.eclipse.mita.platform.arduinouno.connectivity

import com.google.inject.Inject
import java.util.HashMap
import java.util.Map
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.yakindu.base.expressions.expressions.ElementReferenceExpression
import org.yakindu.base.types.Enumerator

class LedGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider

	override generateSetup() {
		val colors = setup.signalToColorAssignment.values.toSet
		
		codeFragmentProvider.create('''
			Retcode_T ledSetupStatus = RETCODE_OK;
			ledSetupStatus = ARD_LED_Connect();
			if(ledSetupStatus != RETCODE_OK)
			{
				return ledSetupStatus;
			}
			«FOR color : colors»
				
				ledSetupStatus = ARD_LED_Enable((uint8_t) «color.handle»);
				if(ledSetupStatus != RETCODE_OK)
				{
					return ledSetupStatus;
				} 		
			«ENDFOR»
		''')
		.setPreamble('''
			«FOR color : colors»
				static bool «color.statusVariable» = false;
			«ENDFOR»
		''')
		.addHeader('ARD_LED.h', false);
	}	
	override generateEnable() {
		CodeFragment.EMPTY;
	}
	
		public static def Map<SignalInstance, String> getSignalToColorAssignment(SystemResourceSetup context) {
		val result = new HashMap<SignalInstance, String>();
		
		context.signalInstances.forEach[vciv | 
			val color = #[vciv.initialization]
				.filter(ElementReferenceExpression)
				.map[x | x.arguments.findFirst[a | a.parameter?.name == 'color']?.value ]
				.filter(ElementReferenceExpression)
				.map[x | x.reference ]
				.filter(Enumerator)
				.map[x | x.name ]
				.head;
				
			result.put(vciv, color);
		]
		
		return result;
	}
	
	private static def getHandle(String color) {
		switch(color) {
			case 'Orange': 'ARD_LED_O'
			case 'Yellow': 'ARD_LED_Y'
			case 'Red': 'ARD_LED_R'
		}
	}
	
	private static def getStatusVariable(String color) {
		'''_ledStatus«color.toFirstUpper»'''
	}

	override generateSignalInstanceSetter(SignalInstance signalInstance, String valueVariableName) {
		val color = setup.signalToColorAssignment.get(signalInstance);
		
		codeFragmentProvider.create('''
			if(*«valueVariableName» == TRUE) {
				ARD_LED_Switch((uint8_t) «color.handle», (uint8_t) LED_COMMAND_ON);
			} else {
				ARD_LED_Switch((uint8_t) «color.handle», (uint8_t) LED_COMMAND_OFF);
			}
			«color.statusVariable» = *«valueVariableName»;
		''')
	}
	

	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
				codeFragmentProvider.create('''
			*«resultName» = «setup.signalToColorAssignment.get(signalInstance).statusVariable»;
		''')
	}
}
