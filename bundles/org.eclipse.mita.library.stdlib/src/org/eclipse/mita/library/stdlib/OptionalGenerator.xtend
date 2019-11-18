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

package org.eclipse.mita.library.stdlib

import com.google.inject.Inject
import java.util.Optional
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.types.CoercionExpression
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.generator.AbstractTypeGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeWithContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.generator.internal.GeneratorRegistry
import org.eclipse.xtext.EcoreUtil2
import java.util.Optional
import org.eclipse.mita.base.typesystem.types.TypeVariable

class OptionalGenerator extends AbstractTypeGenerator {
	
	@Inject
	protected extension GeneratorUtils generatorUtils
	
	@Inject 
	protected extension StatementGenerator statementGenerator
	
	@Inject
	protected GeneratorRegistry registry
		
	public static final String ENUM_NAME = "enumOptional";
	static enum enumOptional {
		None, Some
	}
	public static final String OPTIONAL_FLAG_MEMBER = "flag";
	public static final String OPTIONAL_DATA_MEMBER = "data";
		
	override generateTypeSpecifier(AbstractType type, EObject context) {
		codeFragmentProvider.create('''optional_«typeGenerator.code(context, (type as TypeConstructorType).typeArguments.tail.head)»''').addHeader('MitaGeneratedTypes.h', false);
	}
	
	override generateVariableDeclaration(AbstractType type, EObject context, CodeFragment varName, Expression initialization, boolean isTopLevel) {
		codeFragmentProvider.create('''«typeGenerator.code(context, type)» «varName»;''')
	}
	
	override generateExpression(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, AssignmentOperator operator, CodeWithContext right) {		
		if(operator != AssignmentOperator.ASSIGN) {
			return codeFragmentProvider.create('''ERROR: Unsuported operator: «operator.literal»''')
		}
		val haveInit = right !== null;
		
		val valueExpressionTypeAnnotation = codeFragmentProvider.create('''(«generateTypeSpecifier(left.type, context)») ''');
		
		val validInit = if(right !== null) {
			codeFragmentProvider.create('''«right.code»''');
		}
		else {
			codeFragmentProvider.create('''
			«valueExpressionTypeAnnotation»{
				.«OPTIONAL_FLAG_MEMBER» = «enumOptional.None.name»
			}''')
		}
		
		val initValueIsNone = right === null// || (initIsGeneratedFunction && initAsGeneratedFunction.name == "none");
		
		val firstTypeArgType = (left.type as TypeConstructorType).typeArguments.tail.head;
		val firstTypeArgOrigin = firstTypeArgType.origin;

		
		// Supply a default value and upcast immediates.
		val initWithImmediate = right === null 
			|| (!(firstTypeArgOrigin instanceof GeneratedType));
		
		
		val init = if(initWithImmediate) {
			validInit
		} else {
			if(firstTypeArgType instanceof GeneratedType) {
				// We don't get here (guaranteed by validation), but this is about the code we would produce
				codeFragmentProvider.create('''
				«valueExpressionTypeAnnotation»{
					«IF initValueIsNone»
					.«OPTIONAL_FLAG_MEMBER» = «enumOptional.None.name»
					«ELSE»
					.«OPTIONAL_FLAG_MEMBER» = «enumOptional.Some.name»
					«ENDIF»
				 }
				«IF !initValueIsNone»
				«««this is impossible right now, since we can't reference «left.name».data
				«««registry.getGenerator(firstTypeArgType).generateExpression(firstTypeArg, '''«left.name».«OPTIONAL_DATA_MEMBER»''', AssignmentOperator.ASSIGN, stmt.initialization)»

				«ENDIF»''')
			}
			else {
				//!initIsGeneratedFunction && !firstTypeArg.checkExpressionSupport(AssignmentOperator.ASSIGN, initType))
				//This should only be variable copying with non-generated types
				codeFragmentProvider.create('''«right.code»''')
			}
		}
				
		return codeFragmentProvider.create('''«left.code» = «init.noNewline»''')
	}
	
	override CodeFragment generateHeader() {
		codeFragmentProvider.create('''
		typedef enum {
			«FOR enumVal: enumOptional.values SEPARATOR(", ")» 
			«enumVal.name»
			«ENDFOR»
		} «ENUM_NAME»;
		''')
	}
	
	override CodeFragment generateHeader(EObject context, AbstractType type) {
		val dataType = (type as TypeConstructorType).typeArguments.tail.head;
		if(dataType instanceof TypeVariable) {
			return CodeFragment.EMPTY;
		}
		codeFragmentProvider.create('''
		typedef struct { 
			«typeGenerator.code(context, dataType)» «OPTIONAL_DATA_MEMBER»;
			«ENUM_NAME» «OPTIONAL_FLAG_MEMBER»;
		} «typeGenerator.code(context, type)»;
		''').addHeader('MitaGeneratedTypes.h', false);
	}
	
	override generateCoercion(CoercionExpression expr, AbstractType from, AbstractType to) {
		// this should be a coercion 1 -> some(1).
		val needCast = EcoreUtil2.getContainerOfType(expr, ProgramBlock) !== null;
		return codeFragmentProvider.create('''
			«IF needCast»(«generateTypeSpecifier(to, expr)»)«ENDIF» {
				.data = «expr.value.code»,
				.flag = Some
			}
		''');
	}
	
	override generateBulkCopyStatements(EObject context, CodeFragment i, CodeWithContext left, CodeWithContext right, CodeFragment count) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override generateBulkAllocation(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, CodeFragment count, boolean isTopLevel) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override generateBulkAssignment(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, CodeFragment count) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
}