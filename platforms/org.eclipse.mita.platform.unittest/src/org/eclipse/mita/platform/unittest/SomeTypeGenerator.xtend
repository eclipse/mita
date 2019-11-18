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

package org.eclipse.mita.platform.unittest

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.util.ExpressionUtils
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.AbstractTypeGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CodeWithContext

class SomeTypeGenerator extends AbstractTypeGenerator {
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	override generateVariableDeclaration(AbstractType type, EObject context, CodeFragment varName, Expression initialization, boolean isTopLevel) {
		codeFragmentProvider.create('''«typeGenerator.code(context, (type as TypeConstructorType).typeArguments.tail.head)» «varName»;''');
	}
	
	override generateTypeSpecifier(AbstractType type, EObject context) {
		codeFragmentProvider.create('''«typeGenerator.code(context, (type as TypeConstructorType).typeArguments.tail.head)»''')
	}
		
		
	static class GetElementGenerator extends AbstractFunctionGenerator {
		
		@Inject
		protected CodeFragmentProvider codeFragmentProvider
		
		override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
			val variable = ExpressionUtils.getArgumentValue(functionCall.reference as Operation, functionCall, 'self');
			
			return codeFragmentProvider.create('''«IF resultVariable !== null»«resultVariable.code» = «ENDIF»«variable.generate»''');
		}
		
	}
	
	static class SetElementGenerator extends AbstractFunctionGenerator {
		
		@Inject
		protected CodeFragmentProvider codeFragmentProvider
	
		override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
			val variable = ExpressionUtils.getArgumentValue(functionCall.reference as Operation, functionCall, 'self');
			val value = ExpressionUtils.getArgumentValue(functionCall.reference as Operation, functionCall, 'value');
			
			return codeFragmentProvider.create('''«variable.generate» = «value.generate»;''');
		}
		
	}
	
	override generateBulkCopyStatements(EObject context, CodeFragment i, CodeWithContext left, CodeWithContext right, CodeFragment count) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override generateBulkAllocation(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, CodeFragment count, boolean isTopLevel) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override generateBulkAssignment(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, CodeFragment count) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
}
