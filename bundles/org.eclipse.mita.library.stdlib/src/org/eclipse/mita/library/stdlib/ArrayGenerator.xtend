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
import org.eclipse.mita.base.expressions.ArrayAccessExpression
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.expressions.ValueRange
import org.eclipse.mita.base.expressions.util.ExpressionUtils
import org.eclipse.mita.base.types.CoercionExpression
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.LiteralTypeExpression
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.ArrayLiteral
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.AbstractTypeGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CodeWithContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.generator.TypeGenerator
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.xtext.EcoreUtil2

import static extension org.eclipse.mita.base.types.TypeUtils.ignoreCoercions
import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import org.eclipse.xtend2.lib.StringConcatenationClient
import org.eclipse.mita.base.expressions.Literal
import org.eclipse.mita.base.types.TypeUtils
import org.eclipse.mita.program.model.ModelUtils

class ArrayGenerator extends AbstractTypeGenerator {
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject
	protected extension GeneratorUtils generatorUtils
		
	@Inject 
	protected extension StatementGenerator statementGenerator
	
	@Inject
	protected TypeGenerator typeGenerator
	
	static def getInferredSize(EObject obj) {
		BaseUtils.getType(obj)?.getInferredSize
	}
	static def getInferredSize(AbstractType type) {
		return type?.castOrNull(TypeConstructorType)?.typeArguments?.last?.castOrNull(LiteralTypeExpression) as LiteralTypeExpression<Long>
	}
	
	protected def cf(StringConcatenationClient content) {
		return codeFragmentProvider.create(content);
	}
	
	override CodeFragment generateHeader(EObject context, AbstractType type) {
		if(getDataType(type) instanceof TypeVariable) {
			return CodeFragment.EMPTY;
		}
		cf('''typedef struct «typeGenerator.code(context, type)» «typeGenerator.code(context, type)»;''')
	}
	
	override generateTypeImplementations(EObject context, AbstractType type) {
		if(getDataType(type) instanceof TypeVariable) {
			return CodeFragment.EMPTY;
		}
		cf('''
		struct «typeGenerator.code(context, type)»  {
			«getDataTypeCCode(context, type)»* data;
			uint32_t length;
			uint32_t capacity;
		};
		''').addHeader("inttypes.h", true);
	}
		
	protected def boolean getIsOperationCall(EObject object) {
		if(object instanceof ElementReferenceExpression) {
			return object.isOperationCall && object.reference instanceof Operation;
		}
		return false;
	}
	
	protected def CodeFragment generateBufferStmt(EObject context, AbstractType arrayType, CodeFragment bufferName, CodeFragment size, PrimitiveValueExpression init) {
		return codeFragmentProvider.create('''
			«getDataTypeCCode(context, arrayType)» «bufferName»[«size»]«IF init !== null» = «statementGenerator.code(init)»«ENDIF»;
		''')
	}
	
	override generateGlobalInitialization(AbstractType type, EObject context, CodeFragment varName, Expression initialization) {
		val capacity = type.inferredSize?.eval
		val occurrence = getOccurrence(context);
		val bufferName = cf('''data_«varName»_«occurrence»''');
		return cf('''
			«statementGenerator.generateBulkAssignment(
				context, 
				codeFragmentProvider.create('''«varName»_array'''),
				new CodeWithContext((type as TypeConstructorType).typeArguments.get(1), Optional.empty, bufferName),
				cf('''«capacity»''')
			)»
		''')
	}
	
	override CodeFragment generateVariableDeclaration(AbstractType type, EObject context, CodeFragment varName, Expression initialization, boolean isTopLevel) {
		val capacity = type.inferredSize?.eval
		// if we are top-level, we must do initialization if there is any
		val occurrence = getOccurrence(context);

						
		val bufferName = cf('''data_«varName»_«occurrence»''');
		
		return cf('''
		«IF capacity !== null»
		// buffer for «varName»
		«generateBufferStmt(context, type, bufferName, cf('''«capacity»'''), null)»
		«ELSE»
		ERROR: Couldn't infer size!
		«ENDIF»
		// var «varName»: «type.toString»
		«typeGenerator.code(context, type)» «varName» = «IF !isTopLevel»(«typeGenerator.code(context, type)») «ENDIF»{
			.data = «bufferName»,
			.length = 0,
			.capacity = «capacity»
		};
		«statementGenerator.generateBulkAllocation(
			context, 
			codeFragmentProvider.create('''«varName»_array'''),
			new CodeWithContext((type as TypeConstructorType).typeArguments.get(1), Optional.empty, bufferName),
			cf('''«capacity»'''),
			isTopLevel
		)»
		«IF !isTopLevel»
		«generateGlobalInitialization(type, context, varName, initialization)»
		«ENDIF»
		''').addHeader('MitaGeneratedTypes.h', false);
	}
	
	def AbstractType getDataType(AbstractType t) {
		(t as TypeConstructorType).typeArguments.get(1);
	}
	
	def CodeFragment getDataTypeCCode(EObject context, AbstractType type) {
		typeGenerator.code(context, type.dataType);
	}
	
	override generateTypeSpecifier(AbstractType type, EObject context) {
		cf('''array_«getDataTypeCCode(context, type)»''').addHeader('MitaGeneratedTypes.h', false);
	}
		
	def generateLength(CodeFragment temporaryBufferName, ValueRange valRange, CodeWithContext obj) {
		val objLit = obj.obj.orElse(null)?.castOrNull(PrimitiveValueExpression);
		val inferredSize = obj.type.inferredSize?.eval;
		// array literals aren't translated to a C array object, but directly used for initialization of a buffer.
		// also they are always exactly as long as their member count.  
		return cf(
		'''
			(«IF objLit !== null»«inferredSize»«ELSE»«IF valRange?.upperBound !== null»«valRange.upperBound.code.noTerminator»«ELSE»«obj.code».length«ENDIF»«IF valRange?.lowerBound !== null» - «valRange.lowerBound.code.noTerminator»«ENDIF»«ENDIF»)
		''');
	} 
	
	// returns null if it can't generate this
	dispatch def CodeFragment generateExpression(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, AssignmentOperator operator, CodeWithContext right, ArrayLiteral lit) {
		if(operator != AssignmentOperator.ASSIGN) {
			return null;
		}
		val dataType = left.type.dataType;
		if(!TypeUtils.isGeneratedType(context, dataType)) {
			return cf('''
				«typeGenerator.code(context, dataType)» «cVariablePrefix»_temp_«context.occurrence»[«lit.values.length»] = {«FOR v: lit.values SEPARATOR(", ")»«v.code»«ENDFOR»};
				memcpy(«left.code».data, «cVariablePrefix»_temp_«context.occurrence», sizeof(«typeGenerator.code(context, dataType)»)*«lit.values.length»);
				«left.code».length = «lit.values.length»;
			''').addHeader("string.h", true)
		}
		else {
			return cf('''
				«FOR i_v: lit.values.indexed»
				«statementGenerator.initializationCode(
					context, 
					cf('''«cVariablePrefix»_«i_v.key»'''), 
					new CodeWithContext(dataType, Optional.empty, cf('''«left.code».data[«i_v.key»]''')), 
					operator, 
					new CodeWithContext(dataType, Optional.of(i_v.value), cf('''«i_v.value.code»''')),
					true
				)»
				«ENDFOR»
				«left.code».length = «lit.values.length»;
			''')
		}
	}
	dispatch def CodeFragment generateExpression(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, AssignmentOperator operator, CodeWithContext right, Literal lit) {
		return null;
	}
	dispatch def CodeFragment generateExpression(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, AssignmentOperator operator, CodeWithContext right, Void lit) {
		return null;
	}

	def toCComment(CodeWithContext c) {
		// TODO replace */ with something else
		return c.obj.map[cf('''«ModelUtils.getOriginalSourceCode(it)»''')].orElse(c.code);
	}

	override generateExpression(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, AssignmentOperator operator, CodeWithContext right) {
		if(right === null) {
			return cf('''''')
		}
		val rightLit = right.obj.orElse(null)?.castOrNull(PrimitiveValueExpression)?.value;
		val literalResult = generateExpression(context, cVariablePrefix, left, operator, right, rightLit);
		if(literalResult !== null) {
			return literalResult;
		}
		
		val codeRightExpr = cf('''«right.code.noTerminator.noNewline»''');
		
		val temporaryBufferName = cf('''«cVariablePrefix»_temp_«context.occurrence»''')
		
		val rightObj = right.obj.orElse(null);
		val valRange = if(rightObj instanceof ArrayAccessExpression) {
			if(rightObj.arraySelector instanceof ValueRange) {
				rightObj.arraySelector as ValueRange;	
			}
		}
		
		val lengthLeft = cf('''«left.code».length''')
		val lengthRight = generateLength(temporaryBufferName, valRange, right);
		val capacityLeft = cf('''«left.code».capacity''')
		val remainingCapacityLeft = cf('''«IF operator == AssignmentOperator.ADD_ASSIGN»(«capacityLeft» - «lengthLeft»)«ELSE»«capacityLeft»«ENDIF»''')
		
		val dataLeft = if(operator == AssignmentOperator.ASSIGN) {
			cf('''«left.code».data''');
		}
		else if(operator == AssignmentOperator.ADD_ASSIGN) {
			cf('''(&«left.code».data[«left.code».length])''');
		}
		val dataRight = cf('''
			«IF valRange?.lowerBound !== null»&«ENDIF»«codeRightExpr».data«IF valRange?.lowerBound !== null»[«valRange.lowerBound.code.noTerminator»]«ENDIF»
		''');
		

		val sizeResLeft = Optional.ofNullable(left.type.inferredSize?.eval);
		val sizeResRight = Optional.ofNullable(right.type.inferredSize?.eval);
		
		// if we can infer the sizes we don't need to check bounds 
		// (validation prevents out of bounds compilation for known sizes)
		val staticSize = sizeResLeft.present && sizeResRight.present;

		val capacityCheck = if(!staticSize || operator == AssignmentOperator.ADD_ASSIGN) {
			cf('''
				// do a runtime check since we either don't know the sizes statically or we're appending
				if(«remainingCapacityLeft» < «lengthRight») {
					«generateExceptionHandler(context, "EXCEPTION_INVALIDRANGEEXCEPTION")»
				}
			''')
		}
		else {
			cf('''''')
		}
		
		val staticAccessors = new Object(){
			var field = true;
		};
		// if we can't infer one bound, we set staticAccessors.field to false
		// if x === null, the bound was null, which is valid
		// need object holding boolean, since in lambdas ref'ed vars must be final (== val)
		if(valRange !== null) {
			StaticValueInferrer.infer(valRange.lowerBound, [x| if(x !== null) staticAccessors.field = false])
			StaticValueInferrer.infer(valRange.upperBound, [x| if(x !== null) staticAccessors.field = false])
		}
		 		
		val lengthModifyStmt = cf('''
			«lengthLeft» «operator.literal» «lengthRight»«IF valRange !== null»«IF valRange.lowerBound !== null» - «valRange.lowerBound.code.noTerminator»«ENDIF»«IF valRange.upperBound !== null» - («lengthRight» - «valRange.upperBound.code.noTerminator»)«ENDIF»«ENDIF»;
		''');
		
		
		cf('''
		«capacityCheck»
		/* «left.toCComment» «operator.literal» «right.toCComment» */
		«copyContents(
			context, 
			cf('''«cVariablePrefix»_i'''),
			new CodeWithContext((left.type as TypeConstructorType).typeArguments.get(1), Optional.empty, dataLeft),
			new CodeWithContext((right.type as TypeConstructorType).typeArguments.get(1), Optional.empty, dataRight),
			lengthRight
		)»

		«lengthModifyStmt»
		''').addHeader("string.h", true)
		.addHeader('MitaGeneratedTypes.h', false);
	}
	
	def CodeFragment copyContents(EObject context, CodeFragment i, CodeWithContext left, CodeWithContext right, CodeFragment count) {
		cf('''
			«statementGenerator.generateBulkCopyStatements(context, i,	left, right, count)»
		''')
	}
	
	static class LengthGenerator extends AbstractFunctionGenerator {
		
		@Inject
		protected CodeFragmentProvider codeFragmentProvider
				
		@Inject
		protected extension StatementGenerator
	
		override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
			val variable = ExpressionUtils.getArgumentValue(functionCall.reference as Operation, functionCall, 'self');
			val varref = if(variable !== null) {
				variable.code;
			}
			
			return codeFragmentProvider.create('''«IF resultVariable !== null»«resultVariable.code» = «ENDIF»«varref».length''').addHeader('MitaGeneratedTypes.h', false);
		}
		
		override callShouldBeUnraveled(ElementReferenceExpression expression) {
			false
		}
		
	}
	
	static class CapacityGenerator extends AbstractFunctionGenerator {
		
		@Inject
		protected CodeFragmentProvider codeFragmentProvider
		
		@Inject
		protected extension StatementGenerator
	
		override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
			val variable = ExpressionUtils.getArgumentValue(functionCall.reference as Operation, functionCall, 'self');
			val varref = if(variable !== null) {
				variable.code;
			}
			
			return codeFragmentProvider.create('''«IF resultVariable !== null»«resultVariable.code» = «ENDIF»«varref».capacity''').addHeader('MitaGeneratedTypes.h', false);
		}
		
		override callShouldBeUnraveled(ElementReferenceExpression expression) {
			false
		}
		
	}
	
	override generateCoercion(CoercionExpression expr, AbstractType from, AbstractType to) {
		val inner = expr.value;
		if(inner instanceof ArrayLiteral) {
			return cf('''«inner.code»''');
		}
		return cf('''CANT COERCE «inner.eClass.name»''');
	}
	
	override generateBulkAllocation(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, CodeFragment count, boolean isTopLevel) {
		val arrayType = left.type as TypeConstructorType;
		val dataType = arrayType.typeArguments.get(1);
		val size = cf('''«arrayType.inferredSize?.eval»''');
		return cf('''
			«generateBufferStmt(context, arrayType, cf('''«cVariablePrefix»_buf'''), cf('''«count»*«size»'''), null)»
			
			«statementGenerator.generateBulkAllocation(
				context, 
				codeFragmentProvider.create('''«cVariablePrefix»_array'''),
				new CodeWithContext(dataType, Optional.empty, cf('''«cVariablePrefix»_buf''')),
				cf('''«count»*«size»'''),
				isTopLevel
			)»
		''').addHeader("stddef.h", true)
	}
	
	override generateBulkAssignment(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, CodeFragment count) {
		val arrayType = left.type as TypeConstructorType;
		val dataType = arrayType.typeArguments.get(1);
		val size = cf('''«arrayType.inferredSize?.eval»''');
		val i = cf('''«cVariablePrefix»_i''');
		return cf('''
			for(size_t «i» = 0; «i» < «count»; ++«i») {
				«left.code»[«i»] = («typeGenerator.code(context, arrayType)») {
					.data = &«cVariablePrefix»_buf[«i»*«size»],
					.length = 0,
					.capacity = «size»
				};
			}
			«statementGenerator.generateBulkAssignment(
				context, 
				codeFragmentProvider.create('''«cVariablePrefix»_array'''),
				new CodeWithContext(dataType, Optional.empty, cf('''«cVariablePrefix»_buf''')),
				cf('''«count»*«size»''')
			)»
		''')
	}
	
	override generateBulkCopyStatements(EObject context, CodeFragment i, CodeWithContext left, CodeWithContext right, CodeFragment count) {
		return cf('''
			for(size_t «i» = 0; «i» < «count»; ++«i») {
				«statementGenerator.generateBulkCopyStatements(
					context,
					cf('''ar_«i»'''),
					new CodeWithContext((left.type as TypeConstructorType).typeArguments.get(1), Optional.empty, cf('''«left.code»[«i»].data''')),
					new CodeWithContext((right.type as TypeConstructorType).typeArguments.get(1), Optional.empty, cf('''«right.code»[«i»].data''')),
					cf('''«right.code»[«i»].length''')
				)»
				«left.code»[«i»].length = «right.code»[«i»].length;
			}
		''')
	}
	
}