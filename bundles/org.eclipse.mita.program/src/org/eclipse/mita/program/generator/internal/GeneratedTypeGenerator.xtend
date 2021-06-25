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
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.generator.trace.node.CompositeGeneratorNode
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.ProgramDslTraceExtensions
import java.util.ArrayList
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry

class GeneratedTypeGenerator {
	
	@Inject
	protected extension GeneratorUtils
	
	@Inject
	protected GeneratorRegistry registry

    @Inject
    protected CodeFragmentProvider codeFragmentProvider

	@Inject 
	protected extension ProgramDslTraceExtensions traceExtensions

	private def produceFile(IFileSystemAccess2 fsa, String path, EObject ctx, CompositeGeneratorNode content) {
		var root = CodeFragment.cleanNullChildren(content);
		fsa.generateTracedFile(path, root);
		return path
	}

	def Iterable<String> generateHeaders(IFileSystemAccess2 fsa, EObject resourceOrSetup, CompilationContext context, List<String> userTypeFiles) {
		
		val generatedTypes = context.getAllGeneratedTypesUsed().filterNull.force;
		val generators = generatedTypes.groupBy[it.name].values.map[it.head].map[it -> registry.getGenerator(context.allUnits.head.eResource, it).castOrNull(AbstractTypeGenerator)].filter[it.value !== null].toList;
		
		return generatedTypes.flatMap[
			var _type = it 
			var results = new ArrayList<String>()
			do {
				val type = _type
				val generator = registry.getGenerator(context.allUnits.head.eResource, type).castOrNull(AbstractTypeGenerator)
				if (generator === null) {
					return #[]
				}
				val fileBaseName = resourceOrSetup.getFileNameForTypeImplementation(type)
				val unspecializedFileName = generator.generateUnspecializedDefinitionsHeaderName(resourceOrSetup, type)
				val unspecializedFilePath = "base/generatedTypes/" + unspecializedFileName + ".h"
				
				if (fileBaseName === null) {
					return #[]
				}
				val filePath = resourceOrSetup.getIncludePathForTypeImplementation(type)
				
				results += fsa.produceFile(filePath, resourceOrSetup, codeFragmentProvider.create('''
						«generator.generateHeader(context.allUnits.head, type)»
						«generator.generateTypeImplementations(context.allUnits.head, type)»
					''')
					.addHeader(unspecializedFilePath, false)
					.toHeader(context, '''«fileBaseName»_H'''))
					
				results += fsa.produceFile(unspecializedFilePath, resourceOrSetup, codeFragmentProvider.create('''
					«generator.generateHeader()»
				''').toHeader(context, '''«unspecializedFileName.toUpperCase»_H'''))
					
				if(type.name == StdlibTypeRegistry.referenceTypeQID.segments.last || type.name == StdlibTypeRegistry.optionalTypeQID.segments.last) {
					_type = (type as TypeConstructorType).typeArguments.get(1).castOrNull(TypeConstructorType)	
				}
				else {
					_type = null
				}
			} while(_type !== null)			
			return results
		]
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
		.toImplementation(context);
	}
}
