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

class StructsTest extends AbstractGeneratorTest {
	
	@Test
	def testStructBasic(){
		val ast = generateAndParseApplication(
		'''
		package main;
		import platforms.unittest;

		struct SFoo {
			var bar : uint32;
			var foo : bool;
		}
		''');
		ast.assertNoCompileErrors();
	}
	
	@Test
	def testStructSet(){
		val ast = generateAndParseApplication(
		'''
		package main;
		import platforms.unittest;

		struct SFoo {
			var bar : uint32;
			var foo : bool;
		}
		
		fn foo() {
			var x : SFoo;
			x.bar = 1;
		}
		''');
		ast.assertNoCompileErrors();
	}
	
	@Test
	def testStructGet(){
		val ast = generateAndParseApplication(
		'''
		package main;
		import platforms.unittest;

		struct SFoo {
			var bar : uint32;
			var foo : bool;
		}
		
		fn foo() {
			var x : SFoo;
			var y = x.bar;
		}
		''');
		ast.assertNoCompileErrors();
	}
}