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

import com.google.inject.Inject
import org.eclipse.mita.base.types.AnonymousProductType
import org.eclipse.mita.base.types.ComplexType
import org.eclipse.mita.base.types.EnumerationType
import org.eclipse.mita.base.types.ExceptionTypeDeclaration
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.NamedProductType
import org.eclipse.mita.base.types.NativeType
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.PrimitiveType
import org.eclipse.mita.base.types.Singleton
import org.eclipse.mita.base.types.Type
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.types.typesystem.ITypeSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.program.generator.internal.GeneratorRegistry
import org.eclipse.mita.base.util.BaseUtils

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

	def CodeFragment code(AbstractType type) {
		return if(type === null || !(type.origin instanceof Type)) {
			CodeFragment.EMPTY
		} else {
			code(type.origin as Type, type);
		} 
	}
	
	protected dispatch def CodeFragment code(Singleton singleton, AbstractType typeSpec) {
		return codeFragmentProvider.create('''«singleton.structType»''');
	}
	protected dispatch def CodeFragment code(AnonymousProductType productType, AbstractType typeSpec) {
		// if we have multiple members, we have an actual struct, otherwise we are just an alias
		if(productType.typeSpecifiers.length > 1) {
			return codeFragmentProvider.create('''«productType.structType»''');	
		}
		else {
			return BaseUtils.getType(productType.typeSpecifiers.head).code;
		}
	}
	protected dispatch def CodeFragment code(NamedProductType productType, AbstractType typeSpec) {
		return codeFragmentProvider.create('''«productType.structType»''');
	}
	
	protected dispatch def CodeFragment code(ExceptionTypeDeclaration exception, AbstractType typeSpec) {
		return exceptionGenerator.exceptionType;
	}
	
	protected dispatch def CodeFragment code(GeneratedType type, AbstractType typeSpec) {
		return generatorRegistry.getGenerator(type)?.generateTypeSpecifier(typeSpec, type);
	}
	
	protected dispatch def CodeFragment code(ComplexType type, AbstractType typeSpec) {
		// TODO: find defining resource and header
		return codeFragmentProvider.create('''«type.name»'''); 
	}
	
	protected dispatch def CodeFragment code(EnumerationType type, AbstractType typeSpec) {
		// TODO: find defining resource and header
		return codeFragmentProvider.create('''«type.name»''');
	}
	
	protected dispatch def CodeFragment code(NativeType type, AbstractType typeSpec) {
		var result = codeFragmentProvider.create('''«type.CName»''')
		if(type.header !== null) {
			result = result.addHeader(type.header, true);
		}
		return result;
	}
	
	protected dispatch def CodeFragment code(PrimitiveType type, AbstractType typeSpec) {
		return if(type.name == ITypeSystem.STRING) {
			codeFragmentProvider.create('''char*''');
		} else {
			codeFragmentProvider.create('''«type.name»''');
		}
	}
	
	protected dispatch def CodeFragment code(AbstractSystemResource type, AbstractType typeSpec) {
		throw new UnsupportedOperationException('Cannot use system resources as types yet');
	}
	
	protected dispatch def CodeFragment code(Type type, AbstractType typeSpec) {
		throw new UnsupportedOperationException('''Mita implementation error: missing type «type»''');
	}
	
}