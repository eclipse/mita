package org.eclipse.mita.platform.xdk110.connectivity

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.Enumerator
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.xtext.validation.ValidationMessageAcceptor
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.SystemResourceSetup

class AdcValidator implements IResourceValidator {
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		if(context instanceof SystemResourceSetup) {
			if(context.type?.name == "ADC") {
				context.signalInstances.forEach[validateSigInst(it, acceptor)]
			}
		}
	}
	
	def validateSigInst(SignalInstance context, ValidationMessageAcceptor acceptor) {

		val arg = ModelUtils.getArgumentValue(context, "referenceVoltage");
		val refVoltageEnum = StaticValueInferrer.infer(arg, []);
		if(refVoltageEnum instanceof Enumerator) {
			val refVoltage = refVoltageEnum.name;
			if(refVoltage.contains("Ext") && !referenceVoltageSet(context.eContainer as SystemResourceSetup)) {
				acceptor.acceptError(
				'''You need to set externalReferenceVoltage if you use referenceVoltage=«refVoltage»''',
				arg.eContainer, 
				null, 0, "");
			}
		}		
		
	}
	
	def boolean referenceVoltageSet(SystemResourceSetup setup) {
		return setup.configurationItemValues.exists[ configItem |
			configItem.item.name == "externalReferenceVoltage"
		];
	}
	
}