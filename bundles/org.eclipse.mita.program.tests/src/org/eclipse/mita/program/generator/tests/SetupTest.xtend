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

import org.eclipse.cdt.core.dom.ast.IASTDeclarator
import org.eclipse.cdt.core.dom.ast.IASTEqualsInitializer
import org.eclipse.cdt.core.dom.ast.IASTLiteralExpression
import org.eclipse.cdt.core.dom.ast.IASTSimpleDeclaration
import org.junit.Assert
import org.junit.Test

class SetupTest extends AbstractGeneratorTest {
	
	@Test
	def void testMultipleSetupInstances() {
		val application = '''
			package test;
			import platforms.unittest;
			
			setup a : MyConnectivity {
				cfg00 = "A";
				var s = vci01(10);
			}
			setup b : MyConnectivity {
				cfg00 = "B";
				var s = vci01(10);
			}
		'''
		verifySetupA(application, 'base/ConnectivityMyConnectivityA.c', "cfg00", "\"A\"")
		verifySetupA(application, 'base/ConnectivityMyConnectivityB.c', "cfg00", "\"B\"")
	}
	
	protected def void verifySetupA(String application, String fileName, String configItemName, String expValue) {
		val ast = generateAndParseApplication(application, fileName)
		ast.assertNoCompileErrors();
		val varDecls = ast.value.declarations.filter(IASTSimpleDeclaration).map[it.declarators.head].toList
		val cfgItem = varDecls.findFirst[it.name.toString == configItemName]
		Assert.assertNotNull(cfgItem)
		verifyValue(cfgItem, expValue)
	}
	
	protected def void verifyValue(IASTDeclarator cfg00, String expValue) {
		val init = cfg00.initializer as IASTEqualsInitializer
		val initClause = init.initializerClause as IASTLiteralExpression
		Assert.assertEquals(expValue, String.copyValueOf(initClause.value))
	}
}