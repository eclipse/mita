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
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.library.stdlib.StringGenerator
import org.eclipse.mita.program.InterpolatedStringExpression
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator
import org.eclipse.mita.program.generator.IPlatformLoggingGenerator.LogLevel
import org.eclipse.mita.program.inferrer.StaticValueInferrer

class LogGenerator extends AbstractFunctionGenerator {
	
	@Inject
	protected StringGenerator stringGenerator
	
	@Inject(optional=true)
	protected IPlatformLoggingGenerator loggingGenerator

	
	override generate(EObject target, CodeFragment resultVariableName, ElementReferenceExpression functionCall) {
		val functionName = (functionCall.reference as NamedElement).name;
		val level = switch(functionName) {
			case "logDebug": LogLevel.Debug
			case "logInfo": LogLevel.Info
			case "logWarning": LogLevel.Warning
			case "logError": LogLevel.Error
		}
		
		val firstArg = functionCall.arguments.head?.value;
		val result = if(firstArg instanceof InterpolatedStringExpression) {
			val pattern = stringGenerator.getPattern(firstArg);
			val args = firstArg.content.map[ codeFragmentProvider.create('''«generate(it)»''') ]
			loggingGenerator.generateLogStatement(level, pattern, args);
		} else {
			val pattern = StaticValueInferrer.infer(firstArg, []);
			if(pattern instanceof String) {
				loggingGenerator.generateLogStatement(level, pattern);
			} else {
				codeFragmentProvider.create('''#error «functionName» must only be called with a string literal or interpolated string''')
			}
		}
		
		return result.addHeader('stdio.h', true);
	}
	
}