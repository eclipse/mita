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

package org.eclipse.mita.program.generator

import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.program.generator.internal.GeneratorRegistry
import org.eclipse.mita.types.AnonymousProductType
import org.eclipse.mita.types.ExceptionTypeDeclaration
import org.eclipse.mita.types.GeneratedType
import org.eclipse.mita.types.NamedProductType
import org.eclipse.mita.types.NativeType
import org.eclipse.mita.types.Singleton
import com.google.inject.Inject
import org.yakindu.base.types.ComplexType
import org.yakindu.base.types.EnumerationType
import org.yakindu.base.types.PrimitiveType
import org.yakindu.base.types.Type
import org.yakindu.base.types.typesystem.ITypeSystem
import org.yakindu.base.types.TypeSpecifier

/**
 * Facade for generating types.
 */
class TypeGenerator implements IGenerator {

	@Inject(optional=true)
	protected IPlatformExceptionGenerator exceptionGenerator
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject
	protected GeneratorRegistry generatorRegistry
	
	@Inject
	protected extension GeneratorUtils

	def CodeFragment code(TypeSpecifier typeSpec) {
		return if(typeSpec === null) {
			CodeFragment.EMPTY
		} else {
			code(typeSpec.type, typeSpec);
		} 
	}
	
	protected dispatch def CodeFragment code(Singleton singleton, TypeSpecifier typeSpec) {
		return codeFragmentProvider.create('''«singleton.structType»''');
	}
	protected dispatch def CodeFragment code(AnonymousProductType productType, TypeSpecifier typeSpec) {
		// if we have multiple members, we have an actual struct, otherwise we are just an alias
		if(productType.typeSpecifiers.length > 1) {
			return codeFragmentProvider.create('''«productType.structType»''');	
		}
		else {
			return productType.typeSpecifiers.head.code;
		}
	}
	protected dispatch def CodeFragment code(NamedProductType productType, TypeSpecifier typeSpec) {
		return codeFragmentProvider.create('''«productType.structType»''');
	}
	
	protected dispatch def CodeFragment code(ExceptionTypeDeclaration exception, TypeSpecifier typeSpec) {
		return exceptionGenerator.exceptionType;
	}
	
	protected dispatch def CodeFragment code(GeneratedType type, TypeSpecifier typeSpec) {
		return generatorRegistry.getGenerator(type)?.generateTypeSpecifier(typeSpec, type);
	}
	
	protected dispatch def CodeFragment code(ComplexType type, TypeSpecifier typeSpec) {
		// TODO: find defining resource and header
		return codeFragmentProvider.create('''«type.name»'''); 
	}
	
	protected dispatch def CodeFragment code(EnumerationType type, TypeSpecifier typeSpec) {
		// TODO: find defining resource and header
		return codeFragmentProvider.create('''«type.name»''');
	}
	
	protected dispatch def CodeFragment code(NativeType type, TypeSpecifier typeSpec) {
		var result = codeFragmentProvider.create('''«type.CName»''')
		if(type.header !== null) {
			result = result.addHeader(type.header, true);
		}
		return result;
	}
	
	protected dispatch def CodeFragment code(PrimitiveType type, TypeSpecifier typeSpec) {
		return if(type.name == ITypeSystem.STRING) {
			codeFragmentProvider.create('''char*''');
		} else {
			codeFragmentProvider.create('''«type.name»''');
		}
	}
	
	protected dispatch def CodeFragment code(AbstractSystemResource type, TypeSpecifier typeSpec) {
		throw new UnsupportedOperationException('Cannot use system resources as types yet');
	}
	
	protected dispatch def CodeFragment code(Type type, TypeSpecifier typeSpec) {
		throw new UnsupportedOperationException('''Mita implementation error: missing type «type»''');
	}
	
}