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

import org.eclipse.cdt.core.dom.ast.IASTCompoundStatement
import org.eclipse.cdt.core.dom.ast.IASTExpressionStatement
import org.eclipse.cdt.core.dom.ast.IASTFunctionCallExpression
import org.junit.Test

import static org.junit.Assert.*

class SensorAccessTest extends AbstractGeneratorTest {
	
	@Test
	def testBasicPreparation() {
		val ast = generateAndParseApplication('''
		package main;
		import platforms.unittest;
		
		every 100 milliseconds {
			let mysensorValue = my_sensor00.modality00.read();
		}
		''');
		ast.assertNoCompileErrors();
		
		val eventHandler = ast.value.findFunction("HandleEvery100Millisecond1_worker")
		assertNotNull("No event handler was generated", eventHandler);
		val body = eventHandler.body as IASTCompoundStatement;
		 /*
		  * 0. Retcode_T exception = NO_EXCEPTION;
		  * 1. accessPreparationMock();
		  * 2. int16_t mysensorValue = modalityAccessMock();
		  */
		val preparation = body.statements.get(1);
		if (preparation instanceof IASTExpressionStatement) {
			val expr = preparation.expression;
			if (expr instanceof IASTFunctionCallExpression) {
				assertEquals("Sensor access was not prepared.", "accessPreparationMock", expr.functionNameExpression.rawSignature);
			} else {
				fail("Sensor access was not prepared.");
			}
		} else {
			fail("Sensor access was not prepared.");
		}
	}
	
}