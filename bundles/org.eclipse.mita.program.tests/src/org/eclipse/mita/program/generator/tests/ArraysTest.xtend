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

class ArraysTest extends AbstractGeneratorTest {
	
	@Test
	def testArrays(){
		val ast = generateAndParseApplication(
		'''
		package main;
		import platforms.unittest;

		every 100 milliseconds {
			let a = [1,2,3,4];
			var b = a;
			b = [1,2,3,4,5];
			if(true) {
				b = [1,2,3,4,5,6];
				b = [1,2,3,4,5,6,7];
			}
		}
		''');
		ast.assertNoCompileErrors();
	}
	
	
}