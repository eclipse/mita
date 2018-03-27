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

class EnumsTest extends AbstractGeneratorTest {
	
	@Test
	def testEnumsBasic(){
		val ast = generateAndParseApplication(
		'''
		package main;
		import platforms.unittest;

		enum EFoo {
			Bar,
			Baz,
			Bla
		}
		''');
		ast.assertNoCompileErrors();
	}
	
	@Test
	def testEnumsAssign(){
		val ast = generateAndParseApplication(
		'''
		package main;
		import platforms.unittest;

		enum EFoo {
			Bar,
			Baz,
			Bla
		}
		
		fn foo() {
			var x : EFoo;
			x = EFoo.Baz;
		}
		''');
		ast.assertNoCompileErrors();
	}
	
}