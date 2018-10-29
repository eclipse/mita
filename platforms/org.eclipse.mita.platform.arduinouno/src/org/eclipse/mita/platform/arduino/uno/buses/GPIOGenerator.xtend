package org.eclipse.mita.platform.arduino.uno.buses

import com.google.inject.Inject
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils

class GPIOGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider

	override generateSetup() {
		CodeFragment.EMPTY;
	}

	override generateEnable() {
		codeFragmentProvider.create('''
		«FOR signaleInstace : setup.signalInstances»
		GPIO_Connect(«signaleInstace.pinName», «signaleInstace.pinMode»);
		«ENDFOR»
		''').addHeader("GPIO.h", false)
	}
	
	def CharSequence getPinMode(SignalInstance signaleInstance){
		val init = signaleInstance.initialization as ElementReferenceExpression;
		val value = init.arguments.get(1).value
		if (value instanceof ElementReferenceExpression){
			if(value.reference.toString.contains("INPUT")){
				return "INPUT";
			} else {
				return "OUTPUT";
			}		
		}
	}

	def CodeFragment getPinName(SignalInstance sigInst) {
		val enumValue = StaticValueInferrer.infer(ModelUtils.getArgumentValue(sigInst, "pin"), []);
		if (enumValue instanceof Enumerator) {
			return codeFragmentProvider.create('''«enumValue.name»''');
		}
		return CodeFragment.EMPTY;
	}

	override generateSignalInstanceSetter(SignalInstance signalInstance, String valueVariableName) {
		codeFragmentProvider.create('''
			if(*«valueVariableName») {
				return setGPIO(«signalInstance.pinName»);
			} else {
				return unsetGPIO(«signalInstance.pinName»);
			}
		''')
	}

	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		codeFragmentProvider.create('''return readGPIO(«signalInstance.pinName», «resultName»);''')
	}

}
