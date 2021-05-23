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

import org.eclipse.emf.ecore.EObject;
import org.eclipse.mita.base.typesystem.types.LiteralTypeExpression;
import org.eclipse.mita.base.typesystem.types.TypeConstructorType;
import org.eclipse.mita.base.util.BaseUtils;
import org.eclipse.mita.program.tests.util.AbstractXpectTest;
import org.junit.runner.RunWith;
import org.eclipse.xpect.expectation.IStringExpectation;
import org.eclipse.xpect.expectation.StringExpectation;
import org.eclipse.xpect.runner.Xpect;
import org.eclipse.xpect.runner.XpectRunner;
import org.eclipse.xpect.xtext.lib.setup.ThisOffset;

@RunWith(XpectRunner.class)
public class SignalInstanceTest extends AbstractXpectTest {
	@Xpect
	public void inferredLength(@StringExpectation IStringExpectation expectation, @ThisOffset EObject expr) {
		expectation.assertEquals(((LiteralTypeExpression<?>) ((TypeConstructorType) BaseUtils.getType(expr)).getTypeArguments().get(1)).eval()
				.toString());
	}
}
