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

import org.eclipse.mita.program.InterpolatedStringExpression
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.AbstractTypeGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.ProgramDslTraceExtensions
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.generator.TypeGenerator
import org.eclipse.mita.program.generator.transformation.EscapeWhitespaceInStringStage
import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult
import org.eclipse.mita.program.model.ModelUtils
import com.google.inject.Inject
import java.util.LinkedList
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.generator.trace.node.CompositeGeneratorNode
import org.eclipse.xtext.generator.trace.node.NewLineNode
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.GeneratedFunctionDefinition

class StringGenerator extends AbstractTypeGenerator {
		
	@Inject
	protected ElementSizeInferrer sizeInferrer

	@Inject
	protected extension ProgramDslTraceExtensions
		
	@Inject
	protected ITypeSystemInferrer typeInferrer
	
	@Inject
	protected extension StatementGenerator
	
	@Inject
	protected extension GeneratorUtils
	
	
	private static def Integer getFixedSize(EObject stmt, ElementSizeInferrer sizeInferrer) {
		val inference = sizeInferrer.infer(stmt);
		return if(inference instanceof ValidElementSizeInferenceResult) {
			inference.elementCount;
		} else {
			return -1;
		}
	}
	
	override checkExpressionSupport(TypeSpecifier type, AssignmentOperator operator, TypeSpecifier otherType) {
		var result = false;

		// inline expression support
		result = result || operator === null;
		
		// assign to string
		result = result || (operator == AssignmentOperator.ASSIGN && type.type == otherType.type && type.type?.name == 'string')
		
		// append to string
		result = result || (operator == AssignmentOperator.ADD_ASSIGN && type.type == otherType.type && type.type?.name == 'string')
		
		return result; 
	}
	
	override generateExpression(TypeSpecifier type, EObject left, AssignmentOperator operator, EObject right) {
		return if(operator === null) {
			val stmt = left as EObject;
						
			// inline string interpolation, so let's create a statement expression
			val interpolationCode = generateVariableDeclaration('_str', stmt);
			val trimmedInterpolationCode = interpolationCode.removeAllNewLines;
			codeFragmentProvider.create('''({ «trimmedInterpolationCode.noTerminator»; _str; })''');
		} else if(operator == AssignmentOperator.ASSIGN && left instanceof ReturnStatement) {
			val _right = right as EObject;
			codeFragmentProvider.create('''
			memcpy(*_result, «_right.code.noTerminator», sizeof(«_right.code.noTerminator»));
			''')
			.addHeader('string.h', true);
		} else if(operator == AssignmentOperator.ASSIGN && right instanceof ElementReferenceExpression) {
			val _left = left as EObject;
			val _right = right as EObject;
			codeFragmentProvider.create('''
			memcpy(«_left.code.noTerminator», «_right.code.noTerminator», sizeof(«_right.code.noTerminator»));
			''')
			.addHeader('string.h', true);
		} else if(operator == AssignmentOperator.ADD_ASSIGN) {
			val _left = left as EObject;
			val _right = right as EObject;
			codeFragmentProvider.create('''
			strcat(«_left.code.noTerminator», «_right.code.noTerminator»);
			''')
			.addHeader('string.h', true);
		} else {
			codeFragmentProvider.create('''// TODO: implement string concatenation''')
		}
	}
	
	override generateVariableDeclaration(TypeSpecifier type, VariableDeclaration stmt) {
		return codeFragmentProvider.create(trace(stmt).append(generateVariableDeclaration(stmt.name, stmt.initialization)));
	}
	
	protected def generateVariableDeclaration(String name, EObject initialization) {
		/*
		 * This is an uggly hack. If the container of the initialization is a VariableDeclaration, we infer the size
		 * of the declaration, assuming that the inferrer might take future use of the variable into account. If the
		 * container is of any other type, we infer the size of the initialization. In the latter case we might make
		 * a mistake and allocate too little space.
		 */
		val sizeInferenceResult = if(initialization?.eContainer instanceof VariableDeclaration) {
			sizeInferrer.infer(initialization?.eContainer);
		} else {
			sizeInferrer.infer(initialization);
		}
		val size = if(sizeInferenceResult instanceof ValidElementSizeInferenceResult) {
			sizeInferenceResult.elementCount;
		} else {
			// TOOD: Find a better way to report issues/errors during code generation
			-1;
		}

		if(initialization instanceof InterpolatedStringExpression) {
			codeFragmentProvider.create(
			'''
				char «name»[«size»];
				snprintf(«name», sizeof(«name»), "«initialization.pattern»"«FOR x : initialization.content BEFORE ', ' SEPARATOR ', '»«x.code»«ENDFOR»);
			''')
			.addHeader('stdio.h', true)
			.addHeader('inttypes.h', true)
		} else if(initialization.isOperationCall) {
			val elementReference = initialization as ElementReferenceExpression;
			codeFragmentProvider.create(
			'''
				char «name»[«size + 1»];
			''')
			.addHeader('string.h', true)
			.addHeader('inttypes.h', true)
		} else if(initialization !== null && !(initialization instanceof NewInstanceExpression)) {
			codeFragmentProvider.create(
			'''
				char «name»[«size + 1»];
				const char* _«name»Init = «initialization.code.noTerminator»;
				strcpy(«name», _«name»Init);
			''')
			.addHeader('string.h', true)
			.addHeader('inttypes.h', true)
		} else {
			codeFragmentProvider.create(
			'''
				char «name»[«size + 1»];
			''')
			.addHeader('string.h', true)
		}
	}
	
	protected def boolean getIsOperationCall(EObject object) {
		if(object instanceof ElementReferenceExpression) {
			return object.isOperationCall && object.reference instanceof Operation;
		}
		return false;
	}
	
	def getPattern(InterpolatedStringExpression expression) {
		val tokenizedCode = expression.originalTexts;
		
		var result = "";
		for(var i = 0; i < tokenizedCode.length; i++) {
			val txt = tokenizedCode.get(i);
			result += txt; 
			
			/*
			 * The last token of tokenizedCode can be empty or contain a string,
			 * depending on if the original string ended with an expression or text.
			 * In either case the last token is not followed by an expression.
			 */
			if(i < expression.content.length) {
				val sub = expression.content.get(i);
				if(sub !== null) {
					val type = typeInferrer.infer(sub)?.type;
					var typePattern = switch(type?.name) {
						case 'uint32': '%" PRIu32 "'
						case 'uint16': '%" PRIu16 "'
						case 'uint8': '%" PRIu8 "'
						case 'int32': '%" PRId32 "'
						case 'int16': '%" PRId16 "'
						case 'int8': '%" PRId8 "'
						case 'float': '%f'
						case 'bool': '%d'
						case 'string': '%s'
						default: 'UNKNOWN'
					}
					result += typePattern;				
				}				
			}
		}
		return result;
	}
	
	override generateTypeSpecifier(TypeSpecifier type, EObject context) {
		codeFragmentProvider.create('''char*''')
	}
	
	override generateNewInstance(TypeSpecifier type, NewInstanceExpression expr) {
		CodeFragment.EMPTY;
	}
	
	static def getOriginalTexts(InterpolatedStringExpression expr) {
		val originalSourceCode = ModelUtils.getOriginalSourceCode(expr);
		val codeWithoutBackticks = originalSourceCode.substring(1, originalSourceCode.length - 1);
		
		val results = new LinkedList<String>();
		for(var i = 0; i < codeWithoutBackticks.length; i++) {
			var startOfNextBlock = codeWithoutBackticks.indexOf("${", i);
			if(startOfNextBlock == -1) {
				results.add(codeWithoutBackticks.substring(i, codeWithoutBackticks.length));
				i = codeWithoutBackticks.length;
			} else {
				val endOfNextBlock = codeWithoutBackticks.indexOf("}", startOfNextBlock);
				results.add(codeWithoutBackticks.substring(i, startOfNextBlock));
				i = endOfNextBlock;				
			}
		}
		
		/* This a workaround/hack. Ideally we'd replace the original text in the EscapeWhitespaceInStringStage.
		 * However, as we 'reparse' the original source code this is not possible. Until we find a better solution to work
		 * with interpolated strings we'll be bound to this dependency.
		 */
		return results.map[x | EscapeWhitespaceInStringStage.replaceSpecialCharacters(x) ];
	}

	protected def CompositeGeneratorNode removeAllNewLines(CompositeGeneratorNode node) {
		node.children.removeAll(node.children.filter(NewLineNode));
		node.children.filter(CompositeGeneratorNode).forEach[ removeAllNewLines(it) ]
		return node;
		
	}
	
	static class LengthGenerator extends AbstractFunctionGenerator {
				
		@Inject
		protected ElementSizeInferrer sizeInferrer
	
		override generate(ElementReferenceExpression ref, String resultVariableName) {
			val variable = ModelUtils.getArgumentValue(ref.reference as Operation, ref, 'self');
			val varref = if(variable instanceof ElementReferenceExpression) {
				val varref = variable.reference;
				if(varref instanceof VariableDeclaration) {
					varref
				}
			}
			
			return codeFragmentProvider.create('''«IF resultVariableName !== null»«resultVariableName» = «ENDIF»«varref?.getFixedSize(sizeInferrer)»''');
		}
		
	}
	
}