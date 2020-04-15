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
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.types.InterpolatedStringLiteral
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.library.stdlib.StringGenerator
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.CodeWithContext

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull

class PrintGenerator extends AbstractFunctionGenerator {
	
	@Inject
	protected StringGenerator stringGenerator
	
	override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
		val functionName = (functionCall.reference as NamedElement).name;
		val addBreaklinePostfix = functionName == 'println';
		
//		val firstArg = ref.arguments.head?.value;
//		val result = if(firstArg instanceof InterpolatedStringExpression) {
//			codeFragmentProvider.create('''printf("«stringGenerator.getPattern(firstArg)»«IF addBreaklinePostfix»\n«ENDIF»"«IF !firstArg.content.empty», «FOR arg : firstArg.content SEPARATOR ', '»«generate(arg)»«ENDFOR»«ENDIF»);''')
//				.addHeader('inttypes.h', true);
//		} else {
//			codeFragmentProvider.create('''printf("%s«IF addBreaklinePostfix»\n«ENDIF»", «ref.arguments.head.generate»);

		val firstArg = functionCall.arguments.head?.value;
		val interpolatedStringLiteral = firstArg.castOrNull(PrimitiveValueExpression)?.value?.castOrNull(InterpolatedStringLiteral)
		val result = if(interpolatedStringLiteral !== null) {
			codeFragmentProvider.create('''printf("«stringGenerator.getPattern(interpolatedStringLiteral)»«IF addBreaklinePostfix»\n«ENDIF»"«IF !interpolatedStringLiteral.content.empty», «FOR arg : interpolatedStringLiteral.content SEPARATOR ', '»«stringGenerator.getDataHandleForPrintf(arg)»«ENDFOR»«ENDIF»);''')
				.addHeader('inttypes.h', true);
		} else {
			val expr = functionCall.arguments.head.value;
			codeFragmentProvider.create('''printf("«stringGenerator.getPattern(expr)»«IF addBreaklinePostfix»\n«ENDIF»", «stringGenerator.getDataHandleForPrintf(expr)»);
			''');
		}
		
		return result.addHeader('stdio.h', true);
	}
	
	override callShouldBeUnraveled(ElementReferenceExpression expression) {
		return false;
	}
	
}