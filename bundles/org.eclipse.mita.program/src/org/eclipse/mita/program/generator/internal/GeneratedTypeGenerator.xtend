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
import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull;
import static extension org.eclipse.mita.base.util.BaseUtils.force;

class GeneratedTypeGenerator {
	
	@Inject
	protected extension GeneratorUtils
	
	@Inject
	protected GeneratorRegistry registry

    @Inject
    protected CodeFragmentProvider codeFragmentProvider

	def generateHeader(CompilationContext context, List<String> userTypeFiles) {
		
		val generatedTypes = context.getAllGeneratedTypesUsed().filterNull.force;
		val generatorsWithTypeSpecs = generatedTypes.map[new Pair(it, registry.getGenerator(context.allUnits.head.eResource, it).castOrNull(AbstractTypeGenerator))].filter[it.value !== null].toList;
		val generators = generatedTypes.groupBy[it.name].values.map[it.head].map[registry.getGenerator(context.allUnits.head.eResource, it).castOrNull(AbstractTypeGenerator)].filterNull.toList;
		
		return codeFragmentProvider.create('''
			«FOR generator: generators SEPARATOR("\n")» 
			«generator.generateHeader()»
			«ENDFOR»
			«"\n"»«««explicit newline

			«FOR type_generator : generatorsWithTypeSpecs.groupBy[
				it.value.generateTypeSpecifier(it.key, context.allUnits.head).toString
			].values.map[it.head] SEPARATOR("\n")»
			«type_generator.value.generateHeader(context.allUnits.head, type_generator.key)»
			«ENDFOR»
			«FOR type_generator : generatorsWithTypeSpecs.groupBy[
				it.value.generateTypeSpecifier(it.key, context.allUnits.head).toString
			].values.map[it.head] SEPARATOR("\n")»
			«type_generator.value.generateTypeImplementations(context.allUnits.head, type_generator.key)»
			«ENDFOR»
		''').addHeader(userTypeFiles.map[new IncludePath(it, false)])
		.toHeader(context, 'MITA_GENERATED_TYPES_H')
	}
	
	def generateImplementation(CompilationContext context, List<String> userTypeFiles) {
		val generatedTypes = context.getAllGeneratedTypesUsed().filterNull.force;
		val generators = generatedTypes.groupBy[it.name].values.map[it.head].map[registry.getGenerator(context.allUnits.head.eResource, it).castOrNull(AbstractTypeGenerator)].filterNull.toList;
		
		return codeFragmentProvider.create('''
			«FOR generator: generators SEPARATOR("\n")» 
			«generator.generateImplementation()»
			«ENDFOR»
			«"\n"»
		''')
		.addHeader("MitaGeneratedTypes.h", false)
		.addHeader(userTypeFiles.map[new IncludePath(it, false)])
		.toImplementation(context);
	}
}
