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
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.Literal
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.expressions.StringLiteral
import org.eclipse.mita.base.expressions.ValueRange
import org.eclipse.mita.base.expressions.util.ExpressionUtils
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.InterpolatedStringLiteral
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.ProgramDslTraceExtensions
import org.eclipse.mita.program.generator.transformation.EscapeWhitespaceInStringStage
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.xtext.generator.trace.node.CompositeGeneratorNode
import org.eclipse.xtext.generator.trace.node.IGeneratorNode
import org.eclipse.xtext.generator.trace.node.NewLineNode

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import org.eclipse.mita.base.typesystem.infra.TypeSizeInferrer

class StringGenerator extends ArrayGenerator {
	
	static public val DOUBLE_PRECISION = 6L;

	@Inject
	protected extension ProgramDslTraceExtensions

	override CodeFragment generateLength(EObject obj, CodeFragment temporaryBufferName, ValueRange valRange, CodeFragment objCodeExpr) {
		return codeFragmentProvider.create('''«doGenerateLength(obj, temporaryBufferName, valRange, objCodeExpr).noNewline»''');
	}
	
	dispatch def CodeFragment doGenerateLength(PrimitiveValueExpression expr, CodeFragment temporaryBufferName, ValueRange valRange, CodeFragment objCodeExpr) {
		return doGenerateLength(expr, temporaryBufferName, valRange, objCodeExpr, expr.value);
	}
	dispatch def CodeFragment doGenerateLength(PrimitiveValueExpression expr, CodeFragment temporaryBufferName, ValueRange valRange, CodeFragment objCodeExpr, InterpolatedStringLiteral l) {
		return codeFragmentProvider.create('''
			«temporaryBufferName»_written
		''');
	}
	dispatch def CodeFragment doGenerateLength(PrimitiveValueExpression expr, CodeFragment temporaryBufferName, ValueRange valRange, CodeFragment objCodeExpr, Literal l) {
		return super.generateLength(expr, temporaryBufferName, valRange, objCodeExpr);
	}
	dispatch def CodeFragment doGenerateLength(PrimitiveValueExpression expr, CodeFragment temporaryBufferName, ValueRange valRange, CodeFragment objCodeExpr, Object l) {
		return super.generateLength(expr, temporaryBufferName, valRange, objCodeExpr);
	}
	dispatch def CodeFragment doGenerateLength(PrimitiveValueExpression expr, CodeFragment temporaryBufferName, ValueRange valRange, CodeFragment objCodeExpr, Void l) {
		return super.generateLength(expr, temporaryBufferName, valRange, objCodeExpr);
	}
	dispatch def CodeFragment doGenerateLength(EObject expr, CodeFragment temporaryBufferName, ValueRange valRange, CodeFragment objCodeExpr) {
		return super.generateLength(expr, temporaryBufferName, valRange, objCodeExpr);
	}
	
	override CodeFragment generateBufferStmt(EObject context, AbstractType arrayType, CodeFragment bufferName, long size, PrimitiveValueExpression init) {
		val value = init?.value;
		return doGenerateBufferStmt(context, arrayType, bufferName, size, init, value);
	}
	
	dispatch def CodeFragment doGenerateBufferStmt(EObject context, AbstractType arrayType, CodeFragment bufferName, long size, PrimitiveValueExpression init, InterpolatedStringLiteral l) {
		// need to allocate size+1 since snprintf always writes a zero byte at the end.
		codeFragmentProvider.create('''
				«getBufferType(context, arrayType)» «bufferName»[«size + 1»] = {0};
				int «bufferName»_written = snprintf(«bufferName», sizeof(«bufferName»), "«l.pattern»"«FOR x : l.content BEFORE ', ' SEPARATOR ', '»«x.getDataHandleForPrintf»«ENDFOR»);
				if(«bufferName»_written > «size») {
					«generateExceptionHandler(context, "EXCEPTION_STRINGFORMATEXCEPTION")»
				}
			''')
			.addHeader('stdio.h', true)
			.addHeader('inttypes.h', true)
	}
	
	dispatch def CodeFragment doGenerateBufferStmt(EObject context, AbstractType arrayType, CodeFragment bufferName, long size, PrimitiveValueExpression init, StringLiteral l) {
		return super.generateBufferStmt(context, arrayType, bufferName, size, init);
	}

	dispatch def CodeFragment doGenerateBufferStmt(EObject context, AbstractType arrayType, CodeFragment bufferName, long size, PrimitiveValueExpression init, Object l) {
		return super.generateBufferStmt(context, arrayType, bufferName, size, init);
	}
	dispatch def CodeFragment doGenerateBufferStmt(EObject context, AbstractType arrayType, CodeFragment bufferName, long size, PrimitiveValueExpression init, Void l) {
		return super.generateBufferStmt(context, arrayType, bufferName, size, init);
	}
	dispatch def CodeFragment doGenerateBufferStmt(EObject context, AbstractType arrayType, CodeFragment bufferName, long size, PrimitiveValueExpression init, Literal l) {
		return codeFragmentProvider.create('''UNKNOWN LITERAL: «l.eClass»''')
	}
		
	dispatch def IGeneratorNode getDataHandleForPrintf(Expression e) {
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
				case 'f32':  '%.' + DOUBLE_PRECISION + 'g'
				case 'f64': '%.' + DOUBLE_PRECISION + 'g'
				case 'bool':   '%d'
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
	
		override generate(ElementReferenceExpression ref, IGeneratorNode resultVariableName) {
			val variable = ExpressionUtils.getArgumentValue(ref.reference as Operation, ref, 'self');
			val varref = if(variable instanceof ElementReferenceExpression) {
				val varref = variable.reference;
				if(varref instanceof VariableDeclaration) {
					varref
				}
			}
			
			return codeFragmentProvider.create('''«IF resultVariableName !== null»«resultVariableName» = «ENDIF»«varref».length''');
		}
		
	}
	
}