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

import com.google.inject.Inject
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragmentProvider

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
		code.create('''// nothing to do''')
	}
	
	override generateEnable() {
		code.create('''// nothing to do''')
	}
	
	override generateAdditionalHeaderContent() {
		code.create('''
			void accessPreparationMock();
			int16_t modalityAccessMock();
		''')
		.addHeader('stdint.h', true);
	}
	
	override generateAdditionalImplementation() {
        codeFragmentProvider.create('''
        void accessPreparationMock() {}
        int16_t modalityAccessMock() { return 42;}
        ''')
    }
	
}