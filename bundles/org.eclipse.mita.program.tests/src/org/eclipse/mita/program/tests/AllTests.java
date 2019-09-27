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

package org.eclipse.mita.program.tests;

import org.junit.runner.RunWith;
import org.junit.runners.Suite;
import org.junit.runners.Suite.SuiteClasses;

import org.eclipse.mita.program.tests.arrays.ArraysTest;
import org.eclipse.mita.program.tests.controlflow.ControlStructuresTest;
import org.eclipse.mita.program.tests.enums.EnumerationsTest;
import org.eclipse.mita.program.tests.events.EventHandlingTest;
import org.eclipse.mita.program.tests.exceptions.ExceptionsTest;
import org.eclipse.mita.program.tests.expressions.ExpressionsTest;
import org.eclipse.mita.program.tests.filename.FileNameTest;
import org.eclipse.mita.program.tests.functions.FunctionsTest;
import org.eclipse.mita.program.tests.id.IDTest;
import org.eclipse.mita.program.tests.linking.LinkingTest;
import org.eclipse.mita.program.tests.modality.ModalityTest;
import org.eclipse.mita.program.tests.optionals.OptionalsTest;
import org.eclipse.mita.program.tests.packages.PackagesTest;
import org.eclipse.mita.program.tests.references.ReferencesTest;
import org.eclipse.mita.program.tests.setup.SetupTest;
import org.eclipse.mita.program.tests.signalinstance.SignalInstanceTest;
import org.eclipse.mita.program.tests.strings.StringsTest;
import org.eclipse.mita.program.tests.structs.StructuresTest;
import org.eclipse.mita.program.tests.sumtypes.SumTypesTest;
import org.eclipse.mita.program.tests.types.TypesTest;
import org.eclipse.mita.program.tests.variables.VariablesTest;

@SuiteClasses({ 
	ExpressionsTest.class,
	FunctionsTest.class, 
	FileNameTest.class,
	ControlStructuresTest.class, 
	VariablesTest.class, 
	ExceptionsTest.class,
	IDTest.class,
	OptionalsTest.class,
	LinkingTest.class,
	EnumerationsTest.class,
	StringsTest.class, 
	ArraysTest.class, 
	StructuresTest.class, 
	SetupTest.class,
	EventHandlingTest.class, 
	PackagesTest.class,
	TypesTest.class,
	SumTypesTest.class, 
	ReferencesTest.class,
	SignalInstanceTest.class,
	ModalityTest.class
})
@RunWith(Suite.class)
public class AllTests {

}
