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
import org.eclipse.mita.base.types.TypeParameter
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer
import org.eclipse.mita.library.stdlib.OptionalGenerator
import org.eclipse.mita.library.stdlib.OptionalGenerator.enumOptional
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.generator.internal.GeneratorRegistry
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.xtext.generator.trace.node.IGeneratorNode

class OptionalsNoneGenerator extends AbstractFunctionGenerator {
	
	@Inject 
	protected extension StatementGenerator statementGenerator
		
	@Inject
	protected ITypeSystemInferrer typeInferrer
	
	@Inject
	protected GeneratorRegistry registry
	
	override generate(ElementReferenceExpression functionCall, IGeneratorNode resultVariableName) {
		// need the optionalGenerator
		val funTypeIR = typeInferrer.infer(functionCall);
		val funType = funTypeIR.type;
		if(!(funType instanceof GeneratedType)) {
			return CodeFragment.EMPTY;
		}
		val optGen = registry.getGenerator(funType as GeneratedType);
				
		codeFragmentProvider.create('''
			«IF resultVariableName === null»
			(«optGen?.generateTypeSpecifier(ModelUtils.toSpecifier(funTypeIR), functionCall)») {
				.«OptionalGenerator.OPTIONAL_FLAG_MEMBER» = «enumOptional.None.name»
			}
			«ELSE»
			«resultVariableName».«OptionalGenerator.OPTIONAL_FLAG_MEMBER» = «enumOptional.None.name»;
			«ENDIF»
		''').addHeader('MitaGeneratedTypes.h', false);
	}	
	
	override callShouldBeUnraveled(ElementReferenceExpression expression) {
		// if we can't fully infer the type we need to unravel
		val refTypeIR = typeInferrer.infer(expression);
		val refType = refTypeIR.type;
		if(!(refType instanceof GeneratedType) || refType.name != "optional") {
			return true;
		}
		return ModelUtils.containsTypeBy(true, [t | t.abstract || t instanceof TypeParameter], refTypeIR);
	}
}