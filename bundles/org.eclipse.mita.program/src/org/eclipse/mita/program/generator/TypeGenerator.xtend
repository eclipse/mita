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
import org.eclipse.mita.base.types.Type
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.program.generator.internal.GeneratorRegistry
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.FloatingType

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

	public dispatch def CodeFragment code(Void type) {	
		CodeFragment.EMPTY
	}
	
	public dispatch def CodeFragment code(AtomicType type) {
		if(type.name == "string") {
			return codeFragmentProvider.create('''char*''');
		}
		return codeFragmentProvider.create('''«type.structType»''');
	}
	public dispatch def CodeFragment code(ProdType type) {
		// if we have multiple members, we have an actual struct, otherwise we are just an alias
		if(type.typeArguments.length > 1) {
			return codeFragmentProvider.create('''«type.structType»''');	
		}
		else {
			return type.typeArguments.head.code;
		}
	}
	
	public dispatch def CodeFragment code(FunctionType type) {
		return codeFragmentProvider.create('''«type.to.code» (*«type.name»)(«type.from.code»)''')
	}
	
	public dispatch def CodeFragment code(TypeConstructorType type) {
		return codeFragmentProvider.create('''«type.name»''')
	}
	
// TODO exceptions are atomic types, should be subtype of atomic
//	public dispatch def CodeFragment code(ExceptionTypeDeclaration exception, AbstractType typeSpec) {
//		return exceptionGenerator.exceptionType;
//	}
	
// TODO types need a flag/generator
//	public dispatch def CodeFragment code(GeneratedType type, AbstractType typeSpec) {
//		return generatorRegistry.getGenerator(type)?.generateTypeSpecifier(typeSpec, type);
//	}
		
	public dispatch def CodeFragment code(SumType type) {
		// TODO: find defining resource and header
		return codeFragmentProvider.create('''«type.structType»''');
	}
	
	public dispatch def CodeFragment code(IntegerType type) {
		var result = codeFragmentProvider.create('''«type.CName»''')
		return result;
	}
	
	public dispatch def CodeFragment code(FloatingType type) {
		var result = codeFragmentProvider.create('''«type.CName»''')
		return result;
	}	
}