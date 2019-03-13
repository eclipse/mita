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
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.library.stdlib.OptionalGenerator
import org.eclipse.mita.library.stdlib.OptionalGenerator.enumOptional
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.generator.internal.GeneratorRegistry
import org.eclipse.xtext.generator.trace.node.IGeneratorNode
import org.eclipse.mita.program.generator.AbstractTypeGenerator
import org.eclipse.emf.ecore.EObject

class OptionalsNoneGenerator extends AbstractFunctionGenerator {
	
	@Inject 
	protected extension StatementGenerator statementGenerator
			
	@Inject
	protected GeneratorRegistry registry
	
	override generate(EObject target, IGeneratorNode resultVariableName, ElementReferenceExpression ref) {
		// need the optionalGenerator
		val funType = BaseUtils.getType(ref);
		val funTypeOrigin = funType.origin;
		if(!(funType instanceof TypeConstructorType)) {
			return CodeFragment.EMPTY;
		}
		val optGen = registry.getGenerator(ref.eResource, funType) as AbstractTypeGenerator;
				
		codeFragmentProvider.create('''
			«IF resultVariableName === null»
			(«optGen?.generateTypeSpecifier(funType, ref)») {
				.«OptionalGenerator.OPTIONAL_FLAG_MEMBER» = «enumOptional.None.name»
			}
			«ELSE»
			«resultVariableName».«OptionalGenerator.OPTIONAL_FLAG_MEMBER» = «enumOptional.None.name»;
			«ENDIF»
		''').addHeader('MitaGeneratedTypes.h', false);
	}	
	
	override callShouldBeUnraveled(ElementReferenceExpression expression) {
		// if we can't fully infer the type we need to unravel
		val refType = BaseUtils.getType(expression);
		if(!(refType instanceof TypeConstructorType) || refType.name != "optional") {
			return true;
		}
		return !refType.freeVars.empty;
	}
}