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

package org.eclipse.mita.program.tests.signalinstance;

import org.junit.runner.RunWith;
import org.xpect.expectation.IStringExpectation;
import org.xpect.expectation.StringExpectation;
import org.xpect.runner.Xpect;
import org.xpect.runner.XpectRunner;
import org.xpect.xtext.lib.setup.ThisOffset;

import com.google.inject.Inject;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.mita.program.inferrer.ElementSizeInferrer;
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult;
import org.eclipse.mita.program.tests.util.AbstractXpectTest;

@RunWith(XpectRunner.class)
public class SignalInstanceTest extends AbstractXpectTest {
	@Inject
	private ElementSizeInferrer elementSizeInferrer;
	@Xpect
	public void inferredSize(@StringExpectation IStringExpectation expectation, @ThisOffset EObject expr) {
		expectation.assertEquals(((ValidElementSizeInferenceResult) elementSizeInferrer.infer(expr)).toString());
	}
}
