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
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.CodeWithContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.TypeGenerator
import java.util.Optional
import java.util.Optional

class SignalInstanceReadWriteGenerator extends AbstractFunctionGenerator {
	
	@Inject
	protected extension GeneratorUtils
	
	@Inject
	protected TypeGenerator typeGenerator
		
	override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
		val resultVariableCode = resultVariable?.code ?: codeFragmentProvider.create('''
			«functionCall.uniqueIdentifier»
		''')
		val firstArg = functionCall.arguments.get(0)?.value;
		val siginst = if(firstArg instanceof ElementReferenceExpression && (firstArg as ElementReferenceExpression).reference instanceof SignalInstance) {
			(firstArg as ElementReferenceExpression).reference as SignalInstance;
		} else {
			firstArg.eAllContents.findFirst[ it instanceof SignalInstance ] as SignalInstance;
		}
		
		val functionName = (functionCall.reference as NamedElement).name;
		if(siginst === null) {
			return codeFragmentProvider.create('''#error No signal instance found in this siginst write call. This should not happen!''')
		} else if(functionName == 'read') {
			return codeFragmentProvider.create('''
			«IF resultVariable === null»««« generate a temporary variable 
			«typeGenerator.code(functionCall, BaseUtils.getType(functionCall))» «resultVariableCode»;
			«ENDIF»
			exception = «siginst.readAccessName»(&«resultVariableCode»);
			«generateExceptionHandler(functionCall, 'exception')»
			''')
			.addHeader(siginst.eContainer.fileBasename + '.h', false)
		} else if(functionName == 'write') {
			val value = functionCall.arguments.get(1).value;
			val variableName = codeFragmentProvider.create('''_new«firstArg.uniqueIdentifier.toFirstUpper»''');
			
			val valueType = BaseUtils.getType(value);
			
			return codeFragmentProvider.create('''
			«statementGenerator.generateVariableDeclaration(valueType, functionCall, Optional.empty, variableName, value, false)»
			exception = «siginst.writeAccessName»(&«variableName»);
			«generateExceptionHandler(functionCall, 'exception')»
			''')
			.addHeader(siginst.eContainer.fileBasename + '.h', false)
		} else {
			return codeFragmentProvider.create('''#error Can only generate code for signal instance read or write''')			
		}
	}
	
	dispatch def AbstractType getSigInstTypeArg(AbstractType type) {
		return type;
	}
	dispatch def AbstractType getSigInstTypeArg(FunctionType type) {
		return type.to.sigInstTypeArg2;
	}
	
	dispatch def AbstractType getSigInstTypeArg2(AbstractType type) {
		return type;
	}
	dispatch def AbstractType getSigInstTypeArg2(TypeConstructorType type) {
		if(type.name == "siginst" && type.typeArguments.tail.size > 0) {
			return type.typeArguments.tail.head;
		}
		return type;
	}
	
}