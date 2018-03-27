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

import org.eclipse.mita.library.stdlib.OptionalGenerator
import org.eclipse.mita.library.stdlib.OptionalGenerator.enumOptional
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.generator.internal.GeneratorRegistry
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.types.GeneratedType
import com.google.inject.Inject
import org.yakindu.base.expressions.expressions.ElementReferenceExpression
import org.yakindu.base.types.inferrer.ITypeSystemInferrer
import org.yakindu.base.types.TypeParameter

class OptionalsNoneGenerator extends AbstractFunctionGenerator {
	
	@Inject 
	protected extension StatementGenerator statementGenerator
		
	@Inject
	protected ITypeSystemInferrer typeInferrer
	
	@Inject
	protected GeneratorRegistry registry
	
	override generate(ElementReferenceExpression functionCall, String resultVariableName) {
		// need the optionalGenerator
		val funTypeIR = typeInferrer.infer(functionCall);
		val funType = funTypeIR.type;
		if(!(funType instanceof GeneratedType)) {
			return CodeFragment.EMPTY;
		}
		val optGen = registry.getGenerator(funType as GeneratedType);
				
		codeFragmentProvider.create('''
			«IF resultVariableName === null || resultVariableName.empty»
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