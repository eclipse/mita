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

package org.eclipse.mita.platform.xdk110.connectivity

import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.validation.IResourceValidator
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.validation.ValidationMessageAcceptor

class LedValidator implements IResourceValidator {
	
	override validate(Program program, EObject context, ValidationMessageAcceptor acceptor) {
		if(context instanceof SystemResourceSetup) {
			validateUniqueColorUse(program, context, acceptor);
		}
	}
	
	private def validateUniqueColorUse(Program program, SystemResourceSetup setup, ValidationMessageAcceptor acceptor) {
		// get used colors
		val colorAssignment = LedGenerator.getSignalToColorAssignment(setup);
		val colors = colorAssignment.values.toList;
		
		// check if any of the colors is used more than once
		for(vciAndColor : colorAssignment.entrySet) {
			if(colors.filter[x | vciAndColor.value == x ].length > 1) {
				// we have multiple VCI using the same color. This is bad.
				acceptor.acceptError('The ' + vciAndColor.value.toLowerCase + ' LED can only be used once in the setup.', vciAndColor.key, ProgramPackage.eINSTANCE.variableDeclaration_Initialization, 0, 'LED_USE_NOT_UNIQUE');
			}
		}
	}
		
}