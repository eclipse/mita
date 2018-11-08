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
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.generator.AbstractTypeGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.generator.internal.GeneratorRegistry
import org.eclipse.mita.program.model.ModelUtils

class OptionalGenerator extends AbstractTypeGenerator {
	
	@Inject
	protected extension GeneratorUtils generatorUtils
	
	@Inject 
	protected extension StatementGenerator statementGenerator
	
	@Inject
	protected GeneratorRegistry registry
	
	@Inject
	protected ITypeSystemInferrer typeInferrer
	
	public static final String ENUM_NAME = "enumOptional";
	public static enum enumOptional {
		Some, None
	}
	public static final String OPTIONAL_FLAG_MEMBER = "flag";
	public static final String OPTIONAL_DATA_MEMBER = "data";
	
	override generateNewInstance(TypeSpecifier type, NewInstanceExpression expr) {
		CodeFragment.EMPTY;
	}
	
	override generateTypeSpecifier(TypeSpecifier type, EObject context) {
		codeFragmentProvider.create('''optional_«typeGenerator.code(type.typeArguments.head)»''').addHeader('MitaGeneratedTypes.h', false);
	}
	
	override generateVariableDeclaration(TypeSpecifier type, VariableDeclaration stmt) {
		codeFragmentProvider.create('''«typeGenerator.code(type)» «stmt.name»;''')
	}
	
	override generateExpression(TypeSpecifier type, EObject left, AssignmentOperator operator, EObject right) {
		val isReturnStmt = left instanceof ReturnStatement;
		
		if(operator != AssignmentOperator.ASSIGN) {
			return codeFragmentProvider.create('''ERROR: Unsuported operator: «operator.literal»''')
		}
		val haveInit = right !== null;
		
		val varType = ModelUtils.toSpecifier(typeInferrer.infer(left));
		val initType = if(haveInit) {
			ModelUtils.toSpecifier(typeInferrer.infer(right));
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
		
		val firstTypeArg = varType.typeArguments.head;
		val firstTypeArgType = firstTypeArg.type;
		
		// if we assigned for example a: int32? = 1, right has integer, left has optional<int32>. so we check if left.args.head ~ right. Also we short-circuit none and some and supply a default value.
		val initWithImmediate = initIsGeneratedFunction 
		|| right === null 
		|| (!(firstTypeArgType instanceof GeneratedType) && firstTypeArg.checkExpressionSupport(AssignmentOperator.ASSIGN, initType));
		
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
	
	override CodeFragment generateHeader(TypeSpecifier type) {
		codeFragmentProvider.create('''
		typedef struct { 
			«typeGenerator.code(type.typeArguments.head)» «OPTIONAL_DATA_MEMBER»;
			«ENUM_NAME» «OPTIONAL_FLAG_MEMBER»;
		} «typeGenerator.code(type)»;
		''').addHeader('MitaGeneratedTypes.h', false);
	}
	
	
}