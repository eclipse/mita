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
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.generator.AbstractTypeGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.generator.internal.GeneratorRegistry

class OptionalGenerator extends AbstractTypeGenerator {
	
	@Inject
	protected extension GeneratorUtils generatorUtils
	
	@Inject 
	protected extension StatementGenerator statementGenerator
	
	@Inject
	protected GeneratorRegistry registry
		
	public static final String ENUM_NAME = "enumOptional";
	static enum enumOptional {
		Some, None
	}
	public static final String OPTIONAL_FLAG_MEMBER = "flag";
	public static final String OPTIONAL_DATA_MEMBER = "data";
	
	override generateNewInstance(AbstractType type, NewInstanceExpression expr) {
		CodeFragment.EMPTY;
	}
	
	override generateTypeSpecifier(AbstractType type, EObject context) {
		codeFragmentProvider.create('''optional_«typeGenerator.code(context, (type as TypeConstructorType).typeArguments.head)»''').addHeader('MitaGeneratedTypes.h', false);
	}
	
	override generateVariableDeclaration(AbstractType type, VariableDeclaration stmt) {
		codeFragmentProvider.create('''«typeGenerator.code(stmt, type)» «stmt.name»;''')
	}
	
	override generateExpression(AbstractType type, EObject left, AssignmentOperator operator, EObject right) {
		val isReturnStmt = left instanceof ReturnStatement;
		
		if(operator != AssignmentOperator.ASSIGN) {
			return codeFragmentProvider.create('''ERROR: Unsuported operator: «operator.literal»''')
		}
		val haveInit = right !== null;
		
		val varType = BaseUtils.getType(left);
		val initType = if(haveInit) {
			BaseUtils.getType(right);
		}
		
		val initIsEref = haveInit && right instanceof ElementReferenceExpression;
		val initAsEref = if(initIsEref) {
			right as ElementReferenceExpression;
		}
		
		val initIsOperation = initIsEref && initAsEref.reference instanceof Operation
		val initAsOperation = if(initIsOperation) {
			initAsEref.reference as Operation;
		}
		
		val initIsGeneratedFunction = initAsOperation instanceof GeneratedFunctionDefinition;
		val initAsGeneratedFunction = if(initIsGeneratedFunction) {
			initAsOperation as GeneratedFunctionDefinition;
		}
		
		val validInit = if(initIsGeneratedFunction && initAsGeneratedFunction.name == "some") {
			codeFragmentProvider.create('''«initAsEref.arguments.head.code»''')
		} else if(right !== null) {
			codeFragmentProvider.create('''«right.code»''');
		}
		
		val initValueIsNone = right === null || (initIsGeneratedFunction && initAsGeneratedFunction.name == "none");
		
		val firstTypeArgType = (varType as TypeConstructorType).typeArguments.head;
		val firstTypeArgOrigin = firstTypeArgType.origin;

		
		// if we assigned for example a: int32? = 1, right has integer, left has optional<int32>. so we check if left.args.head ~ right. Also we short-circuit none and some and supply a default value.
		val initWithImmediate = initIsGeneratedFunction 
		|| right === null 
		|| (!(firstTypeArgOrigin instanceof GeneratedType) && firstTypeArgType.checkExpressionSupport(AssignmentOperator.ASSIGN, initType));
		
		val valueExpressionTypeAnnotation = codeFragmentProvider.create('''(«generateTypeSpecifier(type, null)») ''');
		
		val init = if(initWithImmediate) {
			codeFragmentProvider.create('''
			«valueExpressionTypeAnnotation»{
				«IF initValueIsNone»
				.«OPTIONAL_FLAG_MEMBER» = «enumOptional.None.name»
				«ELSE»
				.«OPTIONAL_DATA_MEMBER» = «validInit»,
				.«OPTIONAL_FLAG_MEMBER» = «enumOptional.Some.name»
				«ENDIF»
			};
			''')
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
				 }; 
				«IF !initValueIsNone»
				«««this is impossible right now, since we can't reference «left.name».data
				«««registry.getGenerator(firstTypeArgType).generateExpression(firstTypeArg, '''«left.name».«OPTIONAL_DATA_MEMBER»''', AssignmentOperator.ASSIGN, stmt.initialization)»

				«ENDIF»''')
			}
			else {
				//!initIsGeneratedFunction && !firstTypeArg.checkExpressionSupport(AssignmentOperator.ASSIGN, initType))
				//This should only be variable copying with non-generated types
				codeFragmentProvider.create('''«right.code»;''')
			}
		}
		
		val varNameLeft = if(left instanceof VariableDeclaration) {
			codeFragmentProvider.create('''«left.name»''')
		} else if(isReturnStmt) {
			codeFragmentProvider.create('''*_result''');
		} else {
			codeFragmentProvider.create('''«left.code.noTerminator»''')
		}
		
		codeFragmentProvider.create('''«varNameLeft» = «init.noNewline»''')
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
		codeFragmentProvider.create('''
		typedef struct { 
			«typeGenerator.code(context, (type as TypeConstructorType).typeArguments.head)» «OPTIONAL_DATA_MEMBER»;
			«ENUM_NAME» «OPTIONAL_FLAG_MEMBER»;
		} «typeGenerator.code(context, type)»;
		''').addHeader('MitaGeneratedTypes.h', false);
	}
	
	
}