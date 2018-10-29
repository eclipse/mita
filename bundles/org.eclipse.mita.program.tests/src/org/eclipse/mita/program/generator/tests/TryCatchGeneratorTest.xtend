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

import java.util.ArrayList
import java.util.List
import org.eclipse.cdt.core.dom.ast.IASTBinaryExpression
import org.eclipse.cdt.core.dom.ast.IASTBreakStatement
import org.eclipse.cdt.core.dom.ast.IASTCompoundStatement
import org.eclipse.cdt.core.dom.ast.IASTDeclarationStatement
import org.eclipse.cdt.core.dom.ast.IASTDoStatement
import org.eclipse.cdt.core.dom.ast.IASTExpressionStatement
import org.eclipse.cdt.core.dom.ast.IASTIdExpression
import org.eclipse.cdt.core.dom.ast.IASTIfStatement
import org.eclipse.cdt.core.dom.ast.IASTReturnStatement
import org.eclipse.cdt.core.dom.ast.IASTSimpleDeclaration
import org.eclipse.cdt.core.dom.ast.c.ICASTTypedefNameSpecifier
import org.eclipse.mita.platform.unittest.UnitTestPlatformGeneratorModule.ExceptionGenerator
import org.junit.Test

import static org.junit.Assert.*

class TryCatchGeneratorTest extends AbstractGeneratorTest {
	
	@Test
	def void testCatch() {
		val ast = generateAndParseApplication('''
		package main;
		import platforms.unittest;

		exception FooException;
		
		every 100 milliseconds {
			try {
				
			} catch(FooException) {
				let insideCatchFoo = true;
			} catch(Exception) {
				let insideCatchAll = true;
			}
		}
		''');
		ast.assertNoCompileErrors();
		
		val eventHandler = ast.value.findFunction("HandleEvery100Millisecond1")
		assertNotNull("No event handler was generated", eventHandler);
		val body = eventHandler.body as IASTCompoundStatement;
		
		val tryBlock = body.statements.get(3);
		assertTrue("Try block resulted in something else than a for loop", tryBlock instanceof IASTDoStatement);
		
		val firstCatchStatement = body.children.filter(IASTIfStatement).head;
		var List<IASTIfStatement> catchStatements = new ArrayList<IASTIfStatement>();
		catchStatements += firstCatchStatement;
		for(var catchStatement = firstCatchStatement.elseClause; catchStatement !== null && catchStatement instanceof IASTIfStatement; catchStatement = (catchStatement as IASTIfStatement).elseClause) {
			catchStatements += (catchStatement as IASTIfStatement);
		} 
		// check catch(FooException)
		val fooCatch = catchStatements.get(0);
		assertTrue("Catch FooException block resulted in something else than an if statement", fooCatch instanceof IASTIfStatement);
		val fooCatchIf = fooCatch as IASTIfStatement;
		val fooCatchCondition = fooCatchIf.conditionExpression as IASTBinaryExpression;
		assertEquals("catch(FooException) does not check the exception variable", "exception", (fooCatchCondition.operand1 as IASTIdExpression).name.toString);
		assertTrue("catch(FooException) does not catch FooException", (fooCatchCondition.operand2 as IASTIdExpression).name.toString.toUpperCase.contains("FOOEXCEPTION"));
		assertEquals("catch(FooException) does not catch FooException", IASTBinaryExpression.op_equals, fooCatchCondition.operator);
		assertFalse("catch(FooException) is empty", (fooCatchIf.thenClause as IASTCompoundStatement).children.empty);
		
		// catch catch(Exception)
		val catchAll = catchStatements.get(1);
		assertTrue("Catch Exception block resulted in something else than an if statement", catchAll instanceof IASTIfStatement);
		val catchAllIf = catchAll as IASTIfStatement;
		val catchAllCondition = catchAllIf.conditionExpression as IASTBinaryExpression;
		assertEquals("Catch all does not check the exception variable", "exception", (catchAllCondition.operand1 as IASTIdExpression).name.toString);
		assertEquals("Catch all does not catch all exceptions", "NO_EXCEPTION", (catchAllCondition.operand2 as IASTIdExpression).name.toString);
		assertEquals("Catch all does not catch all exceptions", IASTBinaryExpression.op_notequals, catchAllCondition.operator);
		assertFalse("Catch all is empty", (catchAllIf.thenClause as IASTCompoundStatement).children.empty);
	}
	
	@Test
	def void testThrow() {
		val ast = generateAndParseApplication('''
		package main;
		import platforms.unittest;
		
		exception FooException;
		
		every 100 milliseconds {
			throw FooException;
			
			try {
				throw FooException;
			} catch(FooException) {
				throw FooException;
			} finally {
				throw FooException;
			}
		}
		
		''');
		ast.assertNoCompileErrors();
		
		val eventHandler = ast.value.findFunction("HandleEvery100Millisecond1")
		assertNotNull("No event handler was generated", eventHandler);
		val body = eventHandler.body as IASTCompoundStatement;
		
		// ensure the second statement is the creation of the exception variable (first is generateEventLoopHandlerPreamble)
		val firstExpression = body.statements.get(0);
		if(firstExpression instanceof IASTDeclarationStatement) {
			val expr = firstExpression.declaration;
			if(expr instanceof IASTSimpleDeclaration) {
				val name = expr.declarators.head?.name?.toString;
				assertEquals("exception", name);
				
				val typeName = expr.declSpecifier;
				if(typeName instanceof ICASTTypedefNameSpecifier) {
					assertEquals("Exception variable type is generated by getExceptionType", ExceptionGenerator.EXCEPTION_TYPE, typeName.name.toString);
				} else {
					fail("Exception variable type is generated by getExceptionType");
				}
			} else {
				fail("First statement in handler was not the exception variable.");
			}
		} else {
			fail("First statement in handler was not the exception variable.");
		}
		
		val secondExpression = body.statements.get(1);
		if(secondExpression instanceof IASTDeclarationStatement) {
			val expr = secondExpression.declaration;
			if(expr instanceof IASTSimpleDeclaration) {
				val name = expr.declarators.head?.name?.toString;
				assertEquals("returnFromWithinTryCatch", name);
				
				val typeName = expr.declSpecifier;
				if(typeName instanceof ICASTTypedefNameSpecifier) {
					assertEquals("Early return variable type is boolean", "bool", typeName.name.toString);
				} else {
					fail("Early return variable variable type is boolean");
				}
			} else {
				fail("Second statement in handler was not the early return variable.");
			}
		} else {
			fail("Second statement in handler was not the early return variable.");
		}
		
		// First throw statement should translate to a return statement. Find that return statement
		val thirdExpression = body.statements.get(2);
		assertTrue("Throw outside of try did not translate to return statement", thirdExpression instanceof IASTReturnStatement);
		
		// Try statement should reset the returnFromWithinTryCatch variable
		val resetReturnFromWithinTryCatch = body.statements.get(3);
		
		
		// Try statement should translate to for loop
		val tryBlock = body.statements.get(4);
		assertTrue("Try block resulted in something else than a for loop", tryBlock instanceof IASTDoStatement);
	
		// Throw inside try should become an assignment and break
		val tryBlockContent = ((tryBlock as IASTDoStatement).body as IASTCompoundStatement).statements;
		val tbcFirst = (tryBlockContent.get(0) as IASTExpressionStatement).expression as IASTBinaryExpression;
		assertTrue(tbcFirst.operand1 instanceof IASTIdExpression);
		assertEquals("Throw inside try did not store exception", "exception", (tbcFirst.operand1 as IASTIdExpression).name.toString);
		val tbcSecond = tryBlockContent.get(1);
		assertTrue("Throw inside try did not break program flow", tbcSecond instanceof IASTBreakStatement);
	}
	
	@Test
	def void testMultipleTryCatchBlocks() {
		val ast = generateAndParseApplication('''
		package main;
		import platforms.unittest;
		
		exception FooException;
		
		every 100 milliseconds {
			try {
				let insideTry = true;
			} catch(FooException) {
				let insideCatchFoo = true;
			} catch(Exception) {
				let insideCatchAll = true;
			}
			
			try {
				let insideTry = true;
			} catch(FooException) {
				let insideCatchFoo = true;
			} catch(Exception) {
				let insideCatchAll = true;
			}
		}
		''');
		ast.assertNoCompileErrors();
	}
	
	@Test
	def void testResetInTryCatch() {
		val ast = generateAndParseApplication('''
		package main;
		import platforms.unittest;
		
		exception FooException;
		
		every 100 milliseconds {
			try {
				let insideTry = true;
			} catch(FooException) {
				throw Exception;
			} catch(Exception) {
				// do nothing
			}
		}
		''');
		ast.assertNoCompileErrors();
		
		val eventHandler = ast.value.findFunction("HandleEvery100Millisecond1")
		assertNotNull("No event handler was generated", eventHandler);
		val body = eventHandler.body as IASTCompoundStatement;
		
		val firstCatchStatement = body.children.filter(IASTIfStatement).head;
		var List<IASTIfStatement> catchStatements = new ArrayList<IASTIfStatement>();
		catchStatements += firstCatchStatement;
		for(var catchStatement = firstCatchStatement.elseClause; catchStatement !== null && catchStatement instanceof IASTIfStatement; catchStatement = (catchStatement as IASTIfStatement).elseClause) {
			catchStatements += (catchStatement as IASTIfStatement);
		} 
		assertTrue(catchStatements.length >= 2);
		
		// we expect the exception variable to be set to Exception due to throw statement
		val catchFooException = catchStatements.get(0);
		assertNotNull(catchFooException);
		assertTrue(
			"Throw inside catch is not working",
			catchFooException.descendants.filter(IASTBinaryExpression).exists[
				it.operand1 instanceof IASTIdExpression &&
				it.operand2 instanceof IASTIdExpression &&
				(it.operand1 as IASTIdExpression).name.toString == 'exception' &&
				(it.operand2 as IASTIdExpression).name.toString == 'EXCEPTION_EXCEPTION'
			]);
		
		// we expect the exception variable to be reset to NO_EXCEPTION as no further exception is thrown
		val catchException = catchStatements.get(1);
		assertNotNull(catchException);
		assertTrue(
			"Exception is not reset by the catch statement",
			catchException.thenClause.descendants.filter(IASTBinaryExpression).exists[
				it.operand1 instanceof IASTIdExpression &&
				it.operand2 instanceof IASTIdExpression &&
				(it.operand1 as IASTIdExpression).name.toString == 'exception' &&
				(it.operand2 as IASTIdExpression).name.toString == 'NO_EXCEPTION'
			]);
	}
	
}
