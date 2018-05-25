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

package org.eclipse.mita.program.validation

import org.eclipse.mita.program.Program
import com.google.inject.Inject
import org.eclipse.xtext.validation.AbstractDeclarativeValidator
import org.eclipse.xtext.validation.Check
import org.eclipse.xtext.validation.CheckType
import org.eclipse.xtext.validation.EValidatorRegistrar
import org.yakindu.base.types.Operation

class ProgramNamesAreUniqueValidator extends AbstractDeclarativeValidator {

	val DUPLICATE_ELEMENT = "Duplicate element '%s'"
	val DUPLICATE_FUNCTION = "Duplicate function '%s'"

	@Check(CheckType.FAST)
	def checkGlobalVariableNamesAreUnique(Program program) {
		val names = newArrayList
		program.globalVariables.forEach [
			if (names.contains(name)) {
				error(String.format(DUPLICATE_ELEMENT, name), it, null);
			}
			names.add(name)
		]
	}

	@Check(CheckType.FAST)
	def checkFunctionsAreUnique(Program program) {
		val names = newArrayList
		program.functionDefinitions.forEach [
			if (names.contains(overridingName)) {
				error(String.format(DUPLICATE_FUNCTION, name), it, null);
			}
			names.add(overridingName)
		]
	}

	def protected overridingName(Operation op) {
		'''«op.name»_«FOR param : op.parameters.filter[!optional] SEPARATOR '_'»«param.typeSpecifier?.toString»«ENDFOR»'''.toString
	}

	@Inject
	override register(EValidatorRegistrar registrar) {
		// Do not register because this validator is only a composite #398987
	}
}
