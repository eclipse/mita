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

package org.eclipse.mita.program.generator.tests;

import org.junit.runner.RunWith;
import org.junit.runners.Suite;
import org.junit.runners.Suite.SuiteClasses;

@SuiteClasses({ 
	ArraysTest.class,
	BasicControlStructuresTest.class,
	EnumsTest.class,
	FunctionOverloadingTest.class,
	GlobalAndLocalVariables.class,
	PrepareLoopForFunctionUnvravelingStageTest.class,
	SensorAccessTest.class,
	SetupTest.class,
	StructsTest.class,
	SumTypesTest.class,
	TryCatchGeneratorTest.class,
	UnravelFunctionCallsTest.class
})
@RunWith(Suite.class)
public class AllTests {

}
