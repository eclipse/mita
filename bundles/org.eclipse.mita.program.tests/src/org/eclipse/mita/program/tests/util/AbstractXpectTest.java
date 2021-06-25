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

package org.eclipse.mita.program.tests.util;

import org.junit.runner.RunWith;
import org.eclipse.xpect.runner.XpectRunner;
import org.eclipse.xpect.runner.XpectSuiteClasses;
import org.eclipse.xpect.xtext.lib.tests.LinkingTest;
import org.eclipse.xpect.xtext.lib.tests.ScopingTest;
import org.eclipse.xpect.xtext.lib.tests.ValidationTest;

@RunWith(XpectRunner.class)
@XpectSuiteClasses({ LinkingTest.class, ValidationTest.class, GenerationTest.class, ScopingTest.class, TypeInferrerTest.class})
public abstract class AbstractXpectTest  {
	
}
