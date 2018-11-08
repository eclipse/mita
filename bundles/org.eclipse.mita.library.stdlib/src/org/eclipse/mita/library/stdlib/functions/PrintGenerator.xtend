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

package org.eclipse.mita.library.stdlib.functions

import com.google.inject.Inject
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.library.stdlib.StringGenerator
import org.eclipse.mita.program.InterpolatedStringExpression
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.xtext.generator.trace.node.IGeneratorNode

class PrintGenerator extends AbstractFunctionGenerator {
	
	@Inject
	protected StringGenerator stringGenerator
	
	override generate(ElementReferenceExpression function, IGeneratorNode resultVariableName) {
		val functionName = (function.reference as NamedElement).name;
		val addBreaklinePostfix = functionName == 'println';
		
		val firstArg = function.arguments.head?.value;
		val result = if(firstArg instanceof InterpolatedStringExpression) {
			codeFragmentProvider.create('''printf("«stringGenerator.getPattern(firstArg)»«IF addBreaklinePostfix»\n«ENDIF»"«IF !firstArg.content.empty», «FOR arg : firstArg.content SEPARATOR ', '»«generate(arg)»«ENDFOR»«ENDIF»);''')
				.addHeader('inttypes.h', true);
		} else {
			codeFragmentProvider.create('''printf(«FOR arg : function.arguments SEPARATOR ', '»«generate(arg)»«ENDFOR»);«IF addBreaklinePostfix»
			printf("\n");«ENDIF»''');
		}
		
		return result.addHeader('stdio.h', true);
	}
	
	override callShouldBeUnraveled(ElementReferenceExpression expression) {
		return false;
	}
	
}