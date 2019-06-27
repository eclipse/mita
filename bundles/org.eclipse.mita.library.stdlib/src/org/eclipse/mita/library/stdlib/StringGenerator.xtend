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
import java.util.LinkedList
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.Literal
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.expressions.StringLiteral
import org.eclipse.mita.base.expressions.ValueRange
import org.eclipse.mita.base.expressions.util.ExpressionUtils
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.InterpolatedStringLiteral
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.typesystem.infra.TypeSizeInferrer
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CodeWithContext
import org.eclipse.mita.program.generator.ProgramDslTraceExtensions
import org.eclipse.mita.program.generator.transformation.EscapeWhitespaceInStringStage
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.xtext.generator.trace.node.CompositeGeneratorNode
import org.eclipse.xtext.generator.trace.node.IGeneratorNode
import org.eclipse.xtext.generator.trace.node.NewLineNode

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import java.util.Optional

class StringGenerator extends ArrayGenerator {
	
	@Inject
	protected extension ProgramDslTraceExtensions

	override generateBulkCopyStatements(EObject context, CodeFragment i, CodeWithContext left, CodeWithContext right, CodeFragment count) {
		return cf('''
			for(size_t «i» = 0; «i» < «count»; ++«i») {
				memcpy(«left.code»[«i»].data, «right.code»[«i»].data, sizeof(char) * «right.code»[«i»].length);
				«left.code»[«i»].length = «right.code»[«i»].length;
			}
		''')
	}

	dispatch def CodeFragment generateExpression(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, AssignmentOperator operator, CodeWithContext right, StringLiteral lit) {	
		if(operator != AssignmentOperator.ASSIGN) {
			return null;
		}
		return cf('''
			char «cVariablePrefix»_temp[«lit.value.length»] = "«lit.value»";
			memcpy(«left.code».data, «cVariablePrefix»_temp, sizeof(char)*«lit.value.length»);
			«left.code».length = «lit.value.length»;
		''').addHeader("string.h", true)
	}

	dispatch def CodeFragment generateExpression(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, AssignmentOperator operator, CodeWithContext right, InterpolatedStringLiteral lit) {	
		if(operator != AssignmentOperator.ASSIGN) {
			return null;
		}
		val bufferName = cf('''«cVariablePrefix»_temp''');
		val size = left.type.inferredSize?.eval
		// need to allocate size+1 since snprintf always writes a zero byte at the end.
		return cf('''
			«getBufferType(context, left.type)» «bufferName»[«size + 1»] = {0};
			int «bufferName»_written = snprintf(«bufferName», sizeof(«bufferName»), "«lit.pattern»"«FOR x : lit.content BEFORE ', ' SEPARATOR ', '»«x.getDataHandleForPrintf»«ENDFOR»);
			if(«bufferName»_written > «size») {
				«generateExceptionHandler(context, "EXCEPTION_STRINGFORMATEXCEPTION")»
			}
			memcpy(«left.code».data, «bufferName», sizeof(char)*«bufferName»_written);
			«left.code».length = «bufferName»_written;
		''').addHeader("string.h", true)
	}

	override CodeFragment generateLength(CodeFragment temporaryBufferName, ValueRange valRange, CodeWithContext obj) {
		return codeFragmentProvider.create('''«doGenerateLength(temporaryBufferName, valRange, obj, obj.obj.orElse(null)).noNewline»''');
	}
		
	dispatch def CodeFragment doGenerateLength(CodeFragment temporaryBufferName, ValueRange valRange, CodeWithContext obj, PrimitiveValueExpression expr) {
		return doGenerateLength(temporaryBufferName, valRange, obj, expr, expr.value);
	}
	dispatch def CodeFragment doGenerateLength(CodeFragment temporaryBufferName, ValueRange valRange, CodeWithContext obj, PrimitiveValueExpression expr, InterpolatedStringLiteral l) {
		return codeFragmentProvider.create('''
			«temporaryBufferName»_written
		''');
	}
	dispatch def CodeFragment doGenerateLength(CodeFragment temporaryBufferName, ValueRange valRange, CodeWithContext obj, PrimitiveValueExpression expr, Literal l) {
		return super.generateLength(temporaryBufferName, valRange, obj);
	}
	dispatch def CodeFragment doGenerateLength(CodeFragment temporaryBufferName, ValueRange valRange, CodeWithContext obj, PrimitiveValueExpression expr, Object l) {
		return super.generateLength(temporaryBufferName, valRange, obj);
	}
	dispatch def CodeFragment doGenerateLength(CodeFragment temporaryBufferName, ValueRange valRange, CodeWithContext obj, PrimitiveValueExpression expr, Void l) {
		return super.generateLength(temporaryBufferName, valRange, obj);
	}
	dispatch def CodeFragment doGenerateLength(CodeFragment temporaryBufferName, ValueRange valRange, CodeWithContext obj, EObject expr) {
		return super.generateLength(temporaryBufferName, valRange, obj);
	}
	dispatch def CodeFragment doGenerateLength(CodeFragment temporaryBufferName, ValueRange valRange, CodeWithContext obj, Void expr) {
		return super.generateLength(temporaryBufferName, valRange, obj);
	}
	
	override CodeFragment generateBufferStmt(EObject context, AbstractType arrayType, CodeFragment bufferName, CodeFragment size, PrimitiveValueExpression init) {
		val value = init?.value;
		return doGenerateBufferStmt(context, arrayType, bufferName, size, init, value);
	}
	 
	dispatch def CodeFragment doGenerateBufferStmt(EObject context, AbstractType arrayType, CodeFragment bufferName, CodeFragment size, PrimitiveValueExpression init, InterpolatedStringLiteral l) {
		codeFragmentProvider.create('''
				// need to allocate size+1 since snprintf always writes a zero byte at the end.
				«getBufferType(context, arrayType)» «bufferName»[«size» + 1] = {0};
				int «bufferName»_written = snprintf(«bufferName», sizeof(«bufferName»), "«l.pattern»"«FOR x : l.content BEFORE ', ' SEPARATOR ', '»«x.getDataHandleForPrintf»«ENDFOR»);
				if(«bufferName»_written > «size») {
					«generateExceptionHandler(context, "EXCEPTION_STRINGFORMATEXCEPTION")»
				}
			''')
			.addHeader('stdio.h', true)
			.addHeader('inttypes.h', true)
	}
	
	dispatch def CodeFragment doGenerateBufferStmt(EObject context, AbstractType arrayType, CodeFragment bufferName, CodeFragment size, PrimitiveValueExpression init, StringLiteral l) {
		return super.generateBufferStmt(context, arrayType, bufferName, size, init);
	}

	dispatch def CodeFragment doGenerateBufferStmt(EObject context, AbstractType arrayType, CodeFragment bufferName, CodeFragment size, PrimitiveValueExpression init, Object l) {
		return super.generateBufferStmt(context, arrayType, bufferName, size, init);
	}
	dispatch def CodeFragment doGenerateBufferStmt(EObject context, AbstractType arrayType, CodeFragment bufferName, CodeFragment size, PrimitiveValueExpression init, Void l) {
		return super.generateBufferStmt(context, arrayType, bufferName, size, init);
	}
	dispatch def CodeFragment doGenerateBufferStmt(EObject context, AbstractType arrayType, CodeFragment bufferName, CodeFragment size, PrimitiveValueExpression init, Literal l) {
		return codeFragmentProvider.create('''UNKNOWN LITERAL: «l.eClass»''')
	}
	
	dispatch def IGeneratorNode getDataHandleForPrintf(Expression e) {
		val type = BaseUtils.getType(e);
		if(type !== null) {
			if(type.name == "string") {
				return codeFragmentProvider.create('''«e.code».length, «e.code».data''')
			}
		}
		return e.code;
	}
	dispatch def IGeneratorNode getDataHandleForPrintf(PrimitiveValueExpression e) {
		return e.code;
	}
	dispatch def IGeneratorNode getDataHandleForPrintf(ElementReferenceExpression ref) {
		val type = BaseUtils.getType(ref);
		if(type !== null) {
			if(type.name == "string") {
				return codeFragmentProvider.create('''«ref.code».length, «ref.code».data''');
			}
		}
		return ref.code;
	}
	
	def getPattern(InterpolatedStringLiteral expression) {
		val tokenizedCode = expression.originalTexts.map[it.replaceAll("%", "%%")];
		
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
				val typePattern = getPattern(sub);
				result += typePattern;		
			}
		}
		return result;
	}
	
	def getPattern(Expression sub) {
		if(sub !== null) {
			val type = BaseUtils.getType(sub);
			var typePattern = switch(type?.name) {
				case 'uint32': '%" PRIu32 "'
				case 'uint16': '%" PRIu16 "'
				case 'uint8':  '%" PRIu8 "'
				case 'int32':  '%" PRId32 "'
				case 'int16':  '%" PRId16 "'
				case 'int8':   '%" PRId8 "'
				case 'xint32':  '%" PRId32 "'
				case 'xint16':  '%" PRId16 "'
				case 'xint8':   '%" PRId8 "'
				case 'f32':  '%.' + BaseUtils.DOUBLE_PRECISION + 'g'
				case 'f64': '%.' + BaseUtils.DOUBLE_PRECISION + 'g'
				case 'bool':   '%" PRIu8 "'
				case 'string': if(sub.castOrNull(PrimitiveValueExpression)?.value?.castOrNull(StringLiteral) !== null) {
						'%s'
					}
					else {
						'%.*s'	
					}
				default: 'UNKNOWN'
			}
			return typePattern;
		}	
	}
			
	static def getOriginalTexts(InterpolatedStringLiteral expr) {
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

	override CodeFragment getBufferType(EObject context, AbstractType type) {
		return codeFragmentProvider.create('''char''')
	}

	protected def CompositeGeneratorNode removeAllNewLines(CompositeGeneratorNode node) {
		node.children.removeAll(node.children.filter(NewLineNode));
		node.children.filter(CompositeGeneratorNode).forEach[ removeAllNewLines(it) ]
		return node;
		
	}
	
	static class LengthGenerator extends AbstractFunctionGenerator {
		
		@Inject
		protected CodeFragmentProvider codeFragmentProvider
		
		@Inject
		protected TypeSizeInferrer sizeInferrer
	
		override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
			val variable = ExpressionUtils.getArgumentValue(functionCall.reference as Operation, functionCall, 'self');
			val varref = if(variable instanceof ElementReferenceExpression) {
				val varref = variable.reference;
				if(varref instanceof VariableDeclaration) {
					varref
				}
			}
			
			return codeFragmentProvider.create('''«IF resultVariable !== null»«resultVariable.code» = «ENDIF»«varref».length''');
		}
		
	}
	
}