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
import org.eclipse.mita.program.generator.AbstractTypeGenerator
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

	def generateHeader(CompilationContext context, List<String> userTypeFiles) {
		
		val generatorsWithTypeSpecs = context.getAllGeneratedTypesUsed().map[new Pair(it, registry.getGenerator(context.allUnits.head.eResource, it) as AbstractTypeGenerator)].toList;
		val generators = context.getAllGeneratedTypesUsed().groupBy[it.name].values.map[it.head].map[registry.getGenerator(context.allUnits.head.eResource, it) as AbstractTypeGenerator].toList;
		
		return codeFragmentProvider.create('''
			«FOR generator: generators SEPARATOR("\n")» 
			«generator.generateHeader()»
			«ENDFOR»
			«"\n"»«««explicit newline

			«FOR type_generator : generatorsWithTypeSpecs SEPARATOR("\n")»
			«type_generator.value.generateHeader(type_generator.key)»
			«ENDFOR»
		''').addHeader(userTypeFiles.map[new IncludePath(it, false)])
		.toHeader(context, 'MITA_GENERATED_TYPES_H')
	}
}
