/********************************************************************************
 * Copyright (c) 2019 Robert Bosch GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/
 
package org.eclipse.mita.platform.cgw.connectivity

import java.util.HashMap
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.util.ExpressionUtils
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer.SumTypeRepr
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.xtext.validation.ValidationMessageAcceptor

class LedValidator implements IResourceValidator {
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		if(context instanceof SystemResourceSetup) {
			validateUniqueColorUse(program, context, acceptor);
		}
	}
	
	private def validateUniqueColorUse(Program program, SystemResourceSetup setup, ValidationMessageAcceptor acceptor) {
		// get used colors
		val colorAssignment = getSignalToColorAssignment(setup);
		val colors = colorAssignment.values.toList;
		
		// check if any of the colors is used more than once
		for(vciAndColor : colorAssignment.entrySet) {
			if(colors.filter[x | vciAndColor.value == x ].length > 1) {
				// we have multiple VCI using the same color. This is bad.
				acceptor.acceptError('The ' + vciAndColor.value.toLowerCase + ' LED can only be used once in the setup.', vciAndColor.key, ProgramPackage.eINSTANCE.variableDeclaration_Initialization, 0, 'LED_USE_NOT_UNIQUE');
			}
		}
	}
	
	static def Map<SignalInstance, String> getSignalToColorAssignment(SystemResourceSetup context) {
		val result = new HashMap<SignalInstance, String>();
		
		context.signalInstances.forEach[vciv | 
			val color = #[vciv.initialization]
				.filter(ElementReferenceExpression)
				.map[x | ExpressionUtils.getArgumentValue(x.reference as Operation, x, "color") ]
				.map[ StaticValueInferrer.infer(it, []) ]
				.filter(SumTypeRepr)
				.map[it.name]
				.head;
				
			result.put(vciv, color);
		]
		
		return result;
	}
		
}