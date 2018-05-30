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

package org.eclipse.mita.program.generator.internal

import com.google.inject.Inject
import java.util.List
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer
import org.eclipse.mita.program.generator.CodeFragment.IncludePath
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.GeneratorUtils

class GeneratedTypeGenerator {
	
	@Inject
	protected extension GeneratorUtils
	
	@Inject
	protected GeneratorRegistry registry

    @Inject
    protected CodeFragmentProvider codeFragmentProvider
    
    @Inject ITypeSystemInferrer typeInferrer

	def generateHeader(CompilationContext context, List<String> userTypeFiles) {
		
		val generatorsWithTypeSpecs = context.getAllGeneratedTypesUsed(typeInferrer).map[new Pair(it, registry.getGenerator(it.type as GeneratedType))].toList;
		val generators = context.getAllGeneratedTypesUsed(typeInferrer).map[it.type].groupBy[it.name].values.map[it.head].map[registry.getGenerator(it as GeneratedType)].toList;
		
		return codeFragmentProvider.create('''
			«FOR generator: generators SEPARATOR("\n")» 
			«generator.generateHeader()»
			«ENDFOR»
			«"\n"»«««explicit newline

			«FOR typeSpecifier_generator : generatorsWithTypeSpecs SEPARATOR("\n")»
			«typeSpecifier_generator.value.generateHeader(typeSpecifier_generator.key)»
			«ENDFOR»
		''').addHeader(userTypeFiles.map[new IncludePath(it, false)])
		.toHeader(context, 'MITA_GENERATED_TYPES_H')
	}
	
}