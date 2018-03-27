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

import org.junit.Test

import static org.junit.Assert.*

class FunctionOverloadingTest extends AbstractGeneratorTest {
	
	@Test
	def testPolymorphicFunctions() {
		val ast = generateAndParseApplication('''
		package test;
		import platforms.unittest;
		
		fn notOverloaded(x : uint8) { }
		
		fn overloaded(x : int16) { }
		fn overloaded(x : int32) { }
		
		fn anotherOverloaded(x : int16, y : int32) { }
		fn anotherOverloaded(x : int16, y : bool) { }
		
		''');
		ast.assertNoCompileErrors();
		
		assertNotNull("Function 'notOverloaded' was incorrectly generated", ast.value.findFunction("notOverloaded_uint8"));
		assertNotNull("Function 'overloaded' with int16 parameter was incorrectly generated", ast.value.findFunction("overloaded_int16"));
		assertNotNull("Function 'overloaded' with int32 parameter was incorrectly generated", ast.value.findFunction("overloaded_int32"));
		
		assertNotNull("Function 'anotherOverloaded' with int32 parameter was incorrectly generated", ast.value.findFunction("anotherOverloaded_int16_int32"));
		assertNotNull("Function 'anotherOverloaded' with bool parameter was incorrectly generated", ast.value.findFunction("anotherOverloaded_int16_bool"));
	}
	
}