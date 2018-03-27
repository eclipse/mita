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

package org.eclipse.mita.program.generator.tests

import org.eclipse.cdt.core.dom.ast.IASTBinaryExpression
import org.eclipse.cdt.core.dom.ast.IASTBreakStatement
import org.eclipse.cdt.core.dom.ast.IASTCompoundStatement
import org.eclipse.cdt.core.dom.ast.IASTExpressionStatement
import org.eclipse.cdt.core.dom.ast.IASTForStatement
import org.eclipse.cdt.core.dom.ast.IASTIdExpression
import org.eclipse.cdt.core.dom.ast.IASTIfStatement
import org.eclipse.cdt.core.dom.ast.IASTWhileStatement
import org.junit.Test

import static org.junit.Assert.*
import org.eclipse.cdt.core.dom.ast.IASTDoStatement

class PrepareLoopForFunctionUnvravelingStageTest extends AbstractGeneratorTest {
	
	@Test
	def void testForLoopWithCallInCondition() {
		val ast = generateAndParseApplication('''
		package main;
		import platforms.unittest;

		fn foo() {
			return 10;
		}
		
		fn main() {
			for(var i = 0; i < foo(); i++) {
				print("Hello World\n");
			}
		}
		''')
		
		ast.assertNoCompileErrors();
		
		val mainFunction = ast.value.findFunction("main");
		assertNotNull("No main function was generated", mainFunction);
		val forLoop = mainFunction.body.children.findFirst[it instanceof IASTForStatement] as IASTForStatement;
		assertNotNull("For loop was not generated", mainFunction);
		
		val forCondition = forLoop.conditionExpression;
		assertTrue("For loop condition was not rewritten", forCondition instanceof IASTIdExpression);
		assertEquals("For loop condition was not rewritten to TRUE", "TRUE", (forCondition as IASTIdExpression).name.toString());
		
		(forLoop.body as IASTCompoundStatement).assertHasBreakerIf();
	}
	
	@Test
	def void testForLoopWithCallInPostLoopStatement() {
		val ast = generateAndParseApplication('''
		package main;

		fn foo() {
			return 10;
		}
		
		fn main() {
			for(var i = 0; i < 0; i = foo()) {
				print("Hello World\n");
			}
		}
		''')
		
		ast.assertNoCompileErrors();
		
		val mainFunction = ast.value.findFunction("main");
		assertNotNull("No main function was generated", mainFunction);
		val forLoop = mainFunction.body.children.findFirst[it instanceof IASTForStatement] as IASTForStatement;
		assertNotNull("For loop was not generated", forLoop);
		
		assertNull("Post loop statement was not rewritten", forLoop.iterationExpression);
		
		val lastStatement = (forLoop.body as IASTCompoundStatement).children.last;
		assertTrue("Post loop statement is not the last statement in the loop", lastStatement instanceof IASTExpressionStatement);
		val lastExpression = (lastStatement as IASTExpressionStatement).expression;
		assertTrue("Post loop statement is not the last statement in the loop", lastExpression instanceof IASTBinaryExpression);
		val leftOperand = (lastExpression as IASTBinaryExpression).operand1;
		assertTrue("Post loop statement is not the last statement in the loop", leftOperand instanceof IASTIdExpression);
		assertEquals("Post loop statement is not the last statement in the loop", "i", (leftOperand as IASTIdExpression).name.toString());
	}
	
	@Test
	def void testWhileLoopWithCallInCondition() {
		val ast = generateAndParseApplication('''
		package main;

		fn foo() {
			return 10;
		}
		
		fn main() {
			var i = 0;
			while(i < foo()) {
				print("Hello World\n");
			}
		}
		''')
		
		ast.assertNoCompileErrors();
		
		val mainFunction = ast.value.findFunction("main");
		assertNotNull("No main function was generated", mainFunction);
		val loop = mainFunction.body.children.findFirst[it instanceof IASTWhileStatement] as IASTWhileStatement;
		assertNotNull("For loop was not generated", loop);
		
		val condition = loop.condition;
		assertTrue("For loop condition was not rewritten", condition instanceof IASTIdExpression);
		assertEquals("For loop condition was not rewritten to TRUE", "TRUE", (condition as IASTIdExpression).name.toString());
		
		(loop.body as IASTCompoundStatement).assertHasBreakerIf();
	}
	
	@Test
	def void testDoWhileLoopWithCallInCondition() {
		val ast = generateAndParseApplication('''
		package main;

		fn foo() {
			return 10;
		}
		
		fn main() {
			var i = 0;
			do {
				print("Hello World\n");
			} while(i < foo())
		}
		''')
		
		ast.assertNoCompileErrors();
		
		val mainFunction = ast.value.findFunction("main");
		assertNotNull("No main function was generated", mainFunction);
		val loop = mainFunction.body.children.findFirst[it instanceof IASTDoStatement] as IASTDoStatement;
		assertNotNull("For loop was not generated", loop);
		
		val condition = loop.condition;
		assertTrue("For loop condition was not rewritten", condition instanceof IASTIdExpression);
		assertEquals("For loop condition was not rewritten to TRUE", "TRUE", (condition as IASTIdExpression).name.toString());
		
		(loop.body as IASTCompoundStatement).assertHasBreakerIf();
	}
	
	def void assertHasBreakerIf(IASTCompoundStatement statement) {
		val breakerIf = statement
			.children
			.filter(IASTIfStatement)
			.filter[ it.conditionExpression instanceof IASTBinaryExpression ]
			.findFirst[ 
				val op = it.conditionExpression as IASTBinaryExpression;
				return op.operand1 instanceof IASTIdExpression && ((op.operand1 as IASTIdExpression).name.toString() == "i");
			];
		assertNotNull("No breaker if statement was generated", breakerIf);
		val hasBreakStatement = (breakerIf.thenClause as IASTCompoundStatement).statements.exists[ it instanceof IASTBreakStatement ];
		assertTrue("Breaker if has no break statement", hasBreakStatement);
	}
	
}