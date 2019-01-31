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

import com.google.inject.Inject
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.Program
import org.eclipse.xtext.validation.AbstractDeclarativeValidator
import org.eclipse.xtext.validation.Check
import org.eclipse.xtext.validation.CheckType
import org.eclipse.xtext.validation.EValidatorRegistrar
import org.eclipse.mita.base.typesystem.types.ProdType

class ProgramNamesAreUniqueValidator extends AbstractDeclarativeValidator {

	val DUPLICATE_ELEMENT = "Duplicate element '%s'"
	val DUPLICATE_FUNCTION = "Duplicate function '%s'"
	val DUPLICATE_TYPE = "Duplicate type '%s'"

	@Check(CheckType.FAST)
	def checkGlobalVariableNamesAreUnique(Program program) {
		val names = newArrayList
		program.globalVariables.forEach [
			if (names.contains(name)) {
				error(String.format(DUPLICATE_ELEMENT, name), it, TypesPackage.eINSTANCE.namedElement_Name);
			}
			names.add(name)
		]
	}

	@Check(CheckType.FAST)
	def checkFunctionsAreUnique(Program program) {
		val names = newArrayList
		program.functionDefinitions.forEach [
			if (names.contains(overridingName)) {
				error(String.format(DUPLICATE_FUNCTION, name), it, TypesPackage.eINSTANCE.namedElement_Name);
			}
			names.add(overridingName)
		]
	}

	def protected overridingName(Operation op) {
		val type = BaseUtils.getType(op);
		if(type instanceof FunctionType) {
			val args = type.from;
			if(args instanceof ProdType) {
				return '''«op.name»_«FOR param : args.typeArguments SEPARATOR '_'»«param»«ENDFOR»'''.toString			
			}
		}
		// all functions should have type (FunctionType(ProdType, t)). If not just don't validate, the user's got enough issues already.
		return Math.random.toString
	}

	@Check(CheckType.FAST)
	def checkTypesAreUnique(Program program) {
		val names = newArrayList
		program.types.forEach[
			if (names.contains(it.name)) {
				error(String.format(DUPLICATE_TYPE, it.name), it, TypesPackage.eINSTANCE.namedElement_Name);
			}
			names.add(it.name)
		]
	}

	@Inject
	override register(EValidatorRegistrar registrar) {
		// Do not register because this validator is only a composite #398987
	}
}
