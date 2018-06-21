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

import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.TypeGenerator
import org.eclipse.mita.program.model.ModelUtils
import com.google.inject.Inject
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.FeatureCall

class SignalInstanceReadWriteGenerator extends AbstractFunctionGenerator {
	
	@Inject
	protected extension GeneratorUtils
	
	@Inject
	protected TypeGenerator typeGenerator
	
	override generate(ElementReferenceExpression functionCall, String resultVariableName) {
		val firstArg = functionCall.arguments.get(0)?.value;
		val siginst = if(firstArg instanceof FeatureCall && (firstArg as FeatureCall).feature instanceof SignalInstance) {
			(firstArg as FeatureCall).feature as SignalInstance;
		} else if(firstArg instanceof ElementReferenceExpression && (firstArg as ElementReferenceExpression).reference instanceof SignalInstance) {
			(firstArg as ElementReferenceExpression).reference as SignalInstance;
		} else {
			firstArg.eAllContents.findFirst[ it instanceof SignalInstance ] as SignalInstance;
		}
		
		val functionName = (functionCall.reference as NamedElement).name;
		if(siginst === null) {
			return codeFragmentProvider.create('''#error No signal instance found in this siginst write call. This should not happen!''')
		} else if(functionName == 'read') {
			return codeFragmentProvider.create('''
			exception = «siginst.readAccessName»(&«resultVariableName»);
			«generateExceptionHandler(functionCall, 'exception')»
			''')
			.addHeader(siginst.eContainer.fileBasename + '.h', false)
		} else if(functionName == 'write') {
			val value = functionCall.arguments.get(1).value;
			val variableName = '''_new«firstArg.uniqueIdentifier.toFirstUpper»''';
			
			val siginstType = ModelUtils.toSpecifier(typeInferrer.infer(siginst.instanceOf));
			
			return codeFragmentProvider.create('''
			«typeGenerator.code(siginstType)» «variableName» = «statementGenerator.code(value).noTerminator»;
			exception = «siginst.writeAccessName»(&«variableName»);
			«generateExceptionHandler(functionCall, 'exception')»
			''')
			.addHeader(siginst.eContainer.fileBasename + '.h', false)
		} else {
			return codeFragmentProvider.create('''#error Can only generate code for signal instance read or write''')			
		}
	}
	
}