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

package org.eclipse.mita.program.tests.setup

import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.tests.util.AbstractXpectTest
import org.eclipse.mita.program.tests.util.GenerationTest.ContextObject
import org.eclipse.emf.ecore.EObject
import org.junit.runner.RunWith
import org.xpect.expectation.IStringExpectation
import org.xpect.expectation.StringExpectation
import org.xpect.runner.LiveExecutionType
import org.xpect.runner.Xpect
import org.xpect.runner.XpectRunner

@RunWith(XpectRunner)
class SetupTest extends AbstractXpectTest {

	@Xpect(liveExecution=LiveExecutionType.FAST)
	def void vciParameters(@StringExpectation IStringExpectation expectation, @ContextObject EObject contextObject) {
		var String result;
		
		if (contextObject instanceof SignalInstance) {
			val parameters = contextObject.instanceOf.parameters.parameters.map[ it.name ];
			result = parameters.sort.map[ '''«it»=«StaticValueInferrer.infer(ModelUtils.getArgumentValue(contextObject, it), [])»''' ].join(' ');
		} else {
			result = "vciParameters check can only be used on VCI values"
		}
		
		expectation.assertEquals(result);
	}
	
}
