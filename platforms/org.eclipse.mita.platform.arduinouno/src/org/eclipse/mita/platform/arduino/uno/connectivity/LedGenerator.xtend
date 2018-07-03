package org.eclipse.mita.platform.arduino.uno.connectivity

import com.google.inject.Inject
import java.util.HashMap
import java.util.Map
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider

class LedGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider

	override generateSetup() {
		val colors = setup.signalToColorAssignment.values.toSet
		
		codeFragmentProvider.create('''
			Exception_T ledSetupStatus = STATUS_OK;
			ledSetupStatus = LED_Connect();
			if(ledSetupStatus != STATUS_OK)
			{
				return ledSetupStatus;
			}
			«FOR color : colors»
				
				ledSetupStatus = LED_Enable((uint8_t) «color.handle»);
				if(ledSetupStatus != STATUS_OK)
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
		.addHeader('LED.h', false);
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
			case 'Orange': 'LED_O'
			case 'Yellow': 'LED_Y'
			case 'Red': 'LED_R'
		}
	}
	
	private static def getStatusVariable(String color) {
		'''_ledStatus«color.toFirstUpper»'''
	}

	override generateSignalInstanceSetter(SignalInstance signalInstance, String valueVariableName) {
		val color = setup.signalToColorAssignment.get(signalInstance);
		
		codeFragmentProvider.create('''
			if(*«valueVariableName» == TRUE) {
				LED_Switch((uint8_t) «color.handle», (uint8_t) LED_COMMAND_ON);
			} else {
				LED_Switch((uint8_t) «color.handle», (uint8_t) LED_COMMAND_OFF);
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
