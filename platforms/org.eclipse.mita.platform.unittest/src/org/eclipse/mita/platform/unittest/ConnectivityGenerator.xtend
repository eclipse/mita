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
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.SignalInstance

class ConnectivityGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	CodeFragmentProvider code;
	
	override generateSetup() {
		code.create('''''').setPreamble('''static const char* cfg00 = "«configuration.getString("cfg00")»";''')
	}

	override generateEnable() {
		code.create('''enableMock();''')
	}
	
	override generateSignalInstanceGetter(SignalInstance signalInstance, String resultName) {
		code.create('''generateSignalInstanceGetterMock();''')
	}

	override generateSignalInstanceSetter(SignalInstance signalInstance, String valueVariableName) {
		code.create('''generateSignalInstanceSetterMock();''')
	}
	
	
}
