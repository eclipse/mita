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

package org.eclipse.mita.platform.unittest

import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragmentProvider
import com.google.inject.Inject

class SensorGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	CodeFragmentProvider code;
	
	override generateAccessPreparationFor(ModalityAccessPreparation accessPreparation) {
		code.create('''accessPreparationMock();''')
	}
	
	override generateModalityAccessFor(ModalityAccess modality) {
		code.create('''modalityAccessMock()''')
	}
	
	override generateSetup() {
		code.create('''setupMock();''')
	}
	
	override generateEnable() {
		code.create('''enableMock();''')
	}
	
	override generateAdditionalHeaderContent() {
		code.create('''
			void accessPreparationMock();
			int16_t modalityAccessMock();
			void setupMock();
			void enableMock();	
		''')
		.addHeader('stdint.h', true);
	}
	
}