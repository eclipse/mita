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

package org.eclipse.mita.library.stdlib

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.generator.AbstractTypeGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.base.typesystem.types.TypeConstructorType

class ReferenceGenerator extends AbstractTypeGenerator {
	
	@Inject
	protected extension StatementGenerator
	
	@Inject
	protected extension GeneratorUtils
	
	override generateNewInstance(AbstractType type, NewInstanceExpression expr) {
		CodeFragment.EMPTY;
	}
	
	override generateTypeSpecifier(AbstractType type, EObject context) {
		if(type instanceof TypeConstructorType) {
			val realType = type.typeArguments.get(0);
			val result = super.generateTypeSpecifier(realType, context);
			result.children.add(codeFragmentProvider.create('''*'''));
			return result;			
		} else {
			// We have nothing to dereference here
			return CodeFragment.EMPTY;
		}
		
	}
	
	override generateVariableDeclaration(AbstractType type, VariableDeclaration stmt) {
		codeFragmentProvider.create('''«typeGenerator.code(type)» «stmt.name»«IF stmt.initialization !== null» = «stmt.initialization.code»«ENDIF»;''')
	}
	override generateExpression(AbstractType type, EObject left, AssignmentOperator operator, EObject right) {
		val leftCode = if(left instanceof VariableDeclaration) {
			codeFragmentProvider.create('''«left.name»''');
		} else {
			left.code;
		}
		codeFragmentProvider.create('''«leftCode» «operator.literal» «right.code»;''')
		
	}
	
}