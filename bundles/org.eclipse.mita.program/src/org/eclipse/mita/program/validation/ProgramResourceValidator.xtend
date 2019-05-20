/********************************************************************************
 * Copyright (c) 2019 Robert Bosch GmbH & itemis AG
 * 
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 * 
 * Contributors:
 *    Robert Bosch GmbH & itemis AG - initial contribution
 * 
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/
package org.eclipse.mita.program.validation

import com.google.inject.Inject
import org.eclipse.mita.base.typesystem.infra.MitaBaseResource
import org.eclipse.mita.program.Program
import org.eclipse.xtext.validation.AbstractDeclarativeValidator
import org.eclipse.xtext.validation.Check
import org.eclipse.xtext.validation.CheckType
import org.eclipse.xtext.validation.EValidatorRegistrar

class ProgramResourceValidator extends AbstractDeclarativeValidator {

	public static val MAIN_NOT_ALLOWED_CODE = ""
	public static val MAIN_NOT_ALLOWED_MSG = "File name 'main%s' is not allowed. Rename the file."

	@Check(CheckType.FAST)
	def checkFileNamesAreUnique(Program program) {
		val path = program.eResource.URI.path
		val fileName = path.substring(path.lastIndexOf("/") + 1)
		if (fileName.equals("main" + MitaBaseResource.PROGRAM_EXT)) {
			error(String.format(MAIN_NOT_ALLOWED_MSG, MitaBaseResource.PROGRAM_EXT), null, MAIN_NOT_ALLOWED_CODE)
		}
	}

	@Inject
	override register(EValidatorRegistrar registrar) {
		// Do not register because this validator is only a composite #398987
	}
}
