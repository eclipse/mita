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

import org.eclipse.emf.ecore.EObject;
import org.eclipse.mita.base.typesystem.infra.NicerTypeVariableNamesForErrorMessages;
import org.eclipse.mita.base.util.BaseUtils;
import org.junit.runner.RunWith;
import org.eclipse.xpect.XpectImport;
import org.eclipse.xpect.expectation.IStringExpectation;
import org.eclipse.xpect.expectation.StringExpectation;
import org.eclipse.xpect.runner.Xpect;
import org.eclipse.xpect.runner.XpectRunner;
import org.eclipse.xpect.xtext.lib.setup.ThisOffset;
import org.eclipse.xpect.xtext.lib.setup.XtextStandaloneSetup;
import org.eclipse.xpect.xtext.lib.setup.XtextWorkspaceSetup;

@SuppressWarnings("deprecation")
@RunWith(XpectRunner.class)
@XpectImport({ XtextStandaloneSetup.class, XtextWorkspaceSetup.class })
public class TypeInferrerTest {
	
	@Xpect
	public void inferredType(@StringExpectation IStringExpectation expectation, @ThisOffset EObject expr) {
		NicerTypeVariableNamesForErrorMessages renamer = new NicerTypeVariableNamesForErrorMessages();
		expectation.assertEquals(BaseUtils.getType(expr).modifyNames(renamer));
	}
	
}
