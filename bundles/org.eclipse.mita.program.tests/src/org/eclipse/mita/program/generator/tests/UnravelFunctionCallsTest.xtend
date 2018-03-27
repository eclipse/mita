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

class UnravelFunctionCallsTest extends AbstractGeneratorTest {
	
	@Test
	def testUnravelingOnAssignment() {
		val ast = generateAndParseApplication('''
		package main;
		import platforms.unittest;

		fn foobar() {
			return 10;
		}
		
		every 100 milliseconds {
			var result = foobar();
		}
		''')
		
		ast.assertNoCompileErrors();
	}
	
	@Test
	def testRecursiveUnraveling() {
		val ast = generateAndParseApplication('''
		package main;
		import platforms.unittest;

		fn outerFn(x : int32) {
			return x + 10;
		}
		
		fn innerFn() {
			return 10;
		}
		
		every 100 milliseconds {
			var result = outerFn(innerFn());
		}
		''')
		
		ast.assertNoCompileErrors();
	}
	
	@Test
	def testUnravelingInIfStatements() {
		val ast = generateAndParseApplication('''
		package main;
		import platforms.unittest;

		fn alwaysTrueOuter(x : boolean) {
			return true;
		}
		
		fn alwaysFalse() {
			return false;
		}
		
		every 100 milliseconds {
			if(alwaysTrueOuter(alwaysFalse())) {
				var x = 10;
			}
		}
		''')
		
		ast.assertNoCompileErrors();
	}
	
	@Test
	def testUnravelingInForStatements() {
		val ast = generateAndParseApplication('''
		package main;
		import platforms.unittest;

		fn plusFiveOuter(x : int32) {
			return x + 5;
		}
		
		fn alwaysTen() {
			return 10;
		}
		
		every 100 milliseconds {
			for(var i = 0; i < plusFiveOuter(alwaysTen()); i+=1) {
				var x = 10;
			}
			for(var i = plusFiveOuter(alwaysTen()); i < 10; i+=1) {
				var x = 10;
			}
			for(var i = 0; i < 10; i=plusFiveOuter(alwaysTen())) {
				var x = 10;
			}
		}
		''')
		
		ast.assertNoCompileErrors();
	}
	
	@Test
	def testUnravelingInTryCatch() {
		val ast = generateAndParseApplication('''
		package main;
		import platforms.unittest;

		fn plusFiveOuter(x : int32) {
			return x + 5;
		}
		
		fn alwaysTen() {
			return 10;
		}
		
		every 100 milliseconds {
			try {
				var x = plusFiveOuter(alwaysTen());
			} catch(Exception) {
				// do nothing
			}
		}
		''')
		
		ast.assertNoCompileErrors();
	}
	
	@Test
	def testUnravelingWithSensorAccess() {
		val ast = generateAndParseApplication('''
		package main;
		import platforms.unittest;

		fn plusFiveOuter(x : int32) {
			return x + 5;
		}
		
		fn alwaysTen() {
			return 10;
		}
		
		every 100 milliseconds {
			var x = plusFiveOuter(plusFiveOuter(my_sensor00.modality00.read()));
		}
		''')
		
		ast.assertNoCompileErrors();
	}
	
}