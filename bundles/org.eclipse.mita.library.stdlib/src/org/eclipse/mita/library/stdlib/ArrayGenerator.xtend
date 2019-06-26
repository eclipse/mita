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
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.generator.TypeGenerator
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.generator.trace.node.IGeneratorNode

import static extension org.eclipse.mita.base.types.TypeUtils.ignoreCoercions
import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull
import org.eclipse.mita.program.inferrer.InvalidElementSizeInferenceResult
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.program.generator.CodeWithContext

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
	
	private def long getFixedSize(EObject stmt) {
		return stmt.inferredSize?.eval ?: -1L
	}
	
	override CodeFragment generateHeader(EObject context, AbstractType type) {
		codeFragmentProvider.create('''
		typedef struct {
			«getBufferType(context, type)»* data;
			uint32_t length;
			uint32_t capacity;
		} «typeGenerator.code(context, type)»;
		''').addHeader('MitaGeneratedTypes.h', false);
	}
		
	protected def boolean getIsOperationCall(EObject object) {
		if(object instanceof ElementReferenceExpression) {
			return object.isOperationCall && object.reference instanceof Operation;
		}
		return false;
	}
	
	protected def CodeFragment generateBufferStmt(EObject context, AbstractType arrayType, CodeFragment bufferName, long size, PrimitiveValueExpression init) {
		return codeFragmentProvider.create('''
			«getBufferType(context, arrayType)» «bufferName»[«size»]«IF init !== null» = «statementGenerator.code(init)»«ENDIF»;
		''')
	}
	
	override CodeFragment generateVariableDeclaration(AbstractType type, EObject context, CodeFragment varName, Expression initialization, boolean isTopLevel) {
		val init = initialization.ignoreCoercions;
		val capacity = type.inferredSize?.eval
		// if we are top-level, we must do initialization if there is any
		val occurrence = getOccurrence(context);
		val initValue = init?.castOrNull(PrimitiveValueExpression)
		val initWithValueLiteral = initValue !== null
						
		val bufferName = codeFragmentProvider.create('''data_«varName»_«occurrence»''');
		
		val cf = codeFragmentProvider.create('''
		«IF capacity !== null»
		// buffer for «varName»
		«generateBufferStmt(context, type, bufferName, capacity, initValue)»
		«ELSE»
		ERROR: Couldn't infer size!
		«ENDIF»
		// var «varName»: «type.toString»
		«typeGenerator.code(context, type)» «varName» = {
			.data = data_«varName»_«occurrence»,
			.length = «IF initWithValueLiteral»«getFixedSize(init)»«ELSE»0«ENDIF»,
			.capacity = «capacity»
		};
		''').addHeader('MitaGeneratedTypes.h', false);
		return cf;
	}
	
	def CodeFragment getBufferType(EObject context, AbstractType type) {
		typeGenerator.code(context, (type as TypeConstructorType).typeArguments.tail.head);
	}
	
	override generateTypeSpecifier(AbstractType type, EObject context) {
		codeFragmentProvider.create('''array_«getBufferType(context, type)»''').addHeader('MitaGeneratedTypes.h', false);
	}
	
	override generateNewInstance(CodeFragment varName, AbstractType type, NewInstanceExpression expr) {
		// if we are not in a function we are top-level and must do nothing, since we can't modify top-level anyway
		if(EcoreUtil2.getContainerOfType(expr, FunctionDefinition) === null && EcoreUtil2.getContainerOfType(expr, EventHandlerDeclaration) === null) {
			return CodeFragment.EMPTY;
		}
		
		val capacity = expr.getFixedSize();
		val parent = expr.eContainer;
		val occurrence = getOccurrence(parent);
		
		// variable declarations create the buffer already
		val generateBuffer = (EcoreUtil2.getContainerOfType(expr, VariableDeclaration) === null);
		codeFragmentProvider.create('''
		«IF generateBuffer»
		«typeGenerator.code(expr, (type as TypeConstructorType).typeArguments.tail.head)» data_«varName»_«occurrence»[«capacity»];
		«ENDIF»
		// «varName» = new array<«typeGenerator.code(expr, type)»>(size = «capacity»);
		«varName» = («typeGenerator.code(expr, type)») {
			.data = data_«varName»_«occurrence»,
			.capacity = «capacity»,
			.length = 0
		};
		''').addHeader('MitaGeneratedTypes.h', false);
	}
	
	def generateLength(CodeFragment temporaryBufferName, ValueRange valRange, CodeWithContext obj) {
		val objLit = obj.obj.orElse(null)?.castOrNull(PrimitiveValueExpression);
		return codeFragmentProvider.create(
		'''
			«IF objLit !== null»«obj.type.inferredSize»«ELSE»«IF valRange?.upperBound !== null»«valRange.upperBound.code.noTerminator»«ELSE»«obj.code».length«ENDIF»«IF valRange?.lowerBound !== null» - «valRange.lowerBound.code.noTerminator»«ENDIF»«ENDIF»
		''');
	} 

	override generateExpression(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, AssignmentOperator operator, CodeWithContext right) {
		if(right === null) {
			return codeFragmentProvider.create('''''');
		}
		val rightLit = right.obj.orElse(null)?.castOrNull(PrimitiveValueExpression);
		if(rightLit !== null && left.obj.orElse(null)?.castOrNull(VariableDeclaration) !== null) {
			return CodeFragment.EMPTY;
		}
		
		val codeRightExpr = codeFragmentProvider.create('''«right.code.noTerminator.noNewline»''');
		val rightExprIsValueLit = rightLit !== null;
		
		val temporaryBufferName = codeFragmentProvider.create('''«cVariablePrefix»_temp_«context.occurrence»''')
		
		val valRange = if(right instanceof ArrayAccessExpression) {
			if(right.arraySelector instanceof ValueRange) {
				right.arraySelector as ValueRange;	
			}
		}
		
		val lengthLeft = codeFragmentProvider.create('''«left.code».length''')
		val lengthRight = generateLength(temporaryBufferName, valRange, right);
		val capacityLeft = codeFragmentProvider.create('''«left.code».capacity''')
		val remainingCapacityLeft = codeFragmentProvider.create('''«IF operator == AssignmentOperator.ADD_ASSIGN»(«capacityLeft» - «lengthLeft»)«ELSE»«capacityLeft»«ENDIF»''')
		
		val dataLeft = if(operator == AssignmentOperator.ASSIGN) {
			codeFragmentProvider.create('''«left.code».data''');
		}
		else if(operator == AssignmentOperator.ADD_ASSIGN) {
			codeFragmentProvider.create('''&«left.code».data[«left.code».length]''');
		}
		val dataRight = if(!rightExprIsValueLit) {
			codeFragmentProvider.create('''
				«IF valRange?.lowerBound !== null»&«ENDIF»«codeRightExpr».data«IF valRange?.lowerBound !== null»[«valRange.lowerBound.code.noTerminator»]«ENDIF»
			''');
		} else if(rightExprIsValueLit) {
			temporaryBufferName;	
		}
		

		val sizeResLeft = Optional.ofNullable(left.type.inferredSize);
		val sizeResRight = Optional.ofNullable(right.type.inferredSize);
		
		// if we can infer the sizes we don't need to check bounds 
		// (validation prevents out of bounds compilation for known sizes)
		val staticSize = sizeResLeft.present && sizeResRight.present;

		val capacityCheck = if(!staticSize || operator == AssignmentOperator.ADD_ASSIGN) {
			codeFragmentProvider.create('''
				// do a runtime check since we either don't know the sizes statically or we're appending
				if(«remainingCapacityLeft» < «lengthRight») {
					«generateExceptionHandler(context, "EXCEPTION_INVALIDRANGEEXCEPTION")»
				}
			''')
		}
		else {
			codeFragmentProvider.create()
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
		 		
		val lengthModifyStmt = codeFragmentProvider.create('''
			«lengthLeft» «operator.literal» «lengthRight»«IF valRange !== null»«IF valRange.lowerBound !== null» - «valRange.lowerBound.code.noTerminator»«ENDIF»«IF valRange.upperBound !== null» - («lengthRight» - «valRange.upperBound.code.noTerminator»)«ENDIF»«ENDIF»;
		''');
				
		val typeSize = codeFragmentProvider.create('''sizeof(«getBufferType(context, left.type)»)''')
		
		codeFragmentProvider.create('''
		«IF rightExprIsValueLit»
		// generate buffer to hold immediate
		«generateBufferStmt(context, left.type, temporaryBufferName, getFixedSize(rightLit), rightLit)»
		«ENDIF»
		«capacityCheck»
		// «left.code» «operator.literal» «codeRightExpr»
		memcpy(«dataLeft», «dataRight», «typeSize» * «lengthRight»);
		«lengthModifyStmt»
		''').addHeader('MitaGeneratedTypes.h', false);
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
	
	override generateCoercion(CoercionExpression expr, AbstractType from, AbstractType to) {
		val inner = expr.value;
		if(inner instanceof ArrayLiteral) {
			return codeFragmentProvider.create('''«inner.code»''');
		}
		return codeFragmentProvider.create('''CANT COERCE «inner.eClass.name»''');
	}
	
}