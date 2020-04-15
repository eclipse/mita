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

import org.eclipse.cdt.core.dom.ast.IASTBinaryExpression
import org.eclipse.cdt.core.dom.ast.IASTCompoundStatement
import org.eclipse.cdt.core.dom.ast.IASTDeclarationStatement
import org.eclipse.cdt.core.dom.ast.IASTForStatement
import org.eclipse.cdt.core.dom.ast.IASTLiteralExpression
import org.eclipse.cdt.core.dom.ast.IASTName
import org.eclipse.cdt.core.dom.ast.IASTNode
import org.junit.Test

import static org.junit.Assert.*

class BasicControlStructuresTest extends AbstractGeneratorTest {
	
	@Test
	def testForLoopInEvent() {
		val ast = generateAndParseApplication('''
		package main;
		import platforms.unittest;
		
		every 100 milliseconds {
			for(var i = 0 as uint32; i < 20; i+=1) {
				print("${i}\n");
			}
		}
		''')
		
		ast.assertNoCompileErrors();
		val generatedFunction = ast.value.findFunction("HandleEvery100Millisecond_1_worker");
		assertNotNull("No event handler was generated", generatedFunction);
		val body = generatedFunction.body as IASTCompoundStatement;

		val forloop = body.statements.filter(IASTForStatement).head;
		forloop.checkForLoop();
	}
	
	@Test
	def testForLoopInFunction() {
		val ast = generateAndParseApplication('''
		package main;
		import platforms.unittest;
		
		function foobar() {
			for(var i = 0 as uint32; i < 20; i+=1) {
				print("${i}\n");
			}
		}
		''')
		
		ast.assertNoCompileErrors();
		val generatedFunction = ast.value.findFunction("foobar");
		assertNotNull("No function was generated", generatedFunction);
		val body = generatedFunction.body as IASTCompoundStatement;

		val forloop = body.statements.filter(IASTForStatement).head;
		forloop.checkForLoop();
	}
	
	protected def checkForLoop(IASTNode forloop) {
		if(forloop instanceof IASTForStatement) {
			val init = (forloop.initializerStatement as IASTDeclarationStatement).declaration;
			val initNames = init.descendants.filter(IASTName);
			assertNotNull("Iterator variable not found", initNames.findFirst[x | x.toString() == 'i']);
			assertNotNull("Iterator variable was not uint32_t", initNames.findFirst[x | x.toString() == 'uint32_t']);
			
			val condition = (forloop.conditionExpression);
			if(condition instanceof IASTBinaryExpression) {
				val leftOpVariable = condition.operand1.descendants.filter(IASTName).findFirst[x | x.toString() == 'i' ];
				assertNotNull("Condition did not check iterator variable", leftOpVariable);
				
				assertEquals("Condition had wrong operator", IASTBinaryExpression.op_lessThan, condition.operator);
				
				val rightOpValue = condition.operand2;
				if(rightOpValue instanceof IASTLiteralExpression) {
					assertEquals("Condition checked against wrong value", rightOpValue.value.join(""), "20");
				} else {
					assertTrue("Right condition operand is not a literal", false);
				}
			} else {
				assertTrue("Condition is not a binary expression", false);				
			}
			
			assertNotNull("Iteration expression did not refer to the iterator variable", forloop.iterationExpression.descendants.filter(IASTName).findFirst[x | x.toString() == 'i']);
			
			assertNotNull("For loop body not generated properly", forloop.body.descendants.filter(IASTName).findFirst[x | x.toString() == 'printf']);
		} else {
			assertTrue("For loop not found", false);
		}
	}
	
}