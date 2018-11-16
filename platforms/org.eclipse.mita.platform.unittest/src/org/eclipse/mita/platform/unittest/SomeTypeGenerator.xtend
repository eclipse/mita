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
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.AbstractTypeGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.expressions.util.ExpressionUtils
import org.eclipse.xtext.generator.trace.node.IGeneratorNode

class SomeTypeGenerator extends AbstractTypeGenerator {
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject
	protected ElementSizeInferrer sizeInferrer

	
	
	override generateVariableDeclaration(AbstractType type, VariableDeclaration stmt) {
		codeFragmentProvider.create('''«typeGenerator.code((type as TypeConstructorType).typeArguments.head)» «stmt.name»;''');
	}
	
	override generateTypeSpecifier(AbstractType type, EObject context) {
		codeFragmentProvider.create('''«typeGenerator.code((type as TypeConstructorType).typeArguments.head)»''')
	}
	
	override generateNewInstance(AbstractType type, NewInstanceExpression expr) {
		CodeFragment.EMPTY;
	}
	
		
	static class GetElementGenerator extends AbstractFunctionGenerator {
		
		@Inject
		protected CodeFragmentProvider codeFragmentProvider
		

		override generate(ElementReferenceExpression ref, IGeneratorNode resultVariableName) {
			val variable = ExpressionUtils.getArgumentValue(ref.reference as Operation, ref, 'self');
			
			return codeFragmentProvider.create('''«resultVariableName» = «variable.generate»''');
		}
		
	}
	
	static class SetElementGenerator extends AbstractFunctionGenerator {
		
		@Inject
		protected CodeFragmentProvider codeFragmentProvider
	

		override generate(ElementReferenceExpression ref, IGeneratorNode resultVariableName) {
			val variable = ExpressionUtils.getArgumentValue(ref.reference as Operation, ref, 'self');
			val value = ExpressionUtils.getArgumentValue(ref.reference as Operation, ref, 'value');
			
			return codeFragmentProvider.create('''«variable.generate» = «value.generate»;''');
		}
		
	}
	
}
