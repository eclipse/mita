package org.eclipse.mita.library.stdlib

import com.google.common.base.Optional
import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.util.ExpressionUtils
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.AbstractTypeGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeWithContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.generator.internal.GeneratorRegistry
import org.eclipse.mita.program.inferrer.ElementSizeInferrer
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult
import org.eclipse.xtext.generator.trace.node.IGeneratorNode

// https://www.snellman.net/blog/archive/2016-12-13-ring-buffers/
class RingbufferGenerator extends AbstractTypeGenerator {
	@Inject
	extension GeneratorUtils
	
	override generateHeader(EObject context, AbstractType type) {
		if(type instanceof TypeConstructorType) {
			codeFragmentProvider.create('''
				typedef struct {
					«typeGenerator.code(context, type.typeArguments.tail.head)»* data;
					uint32_t read;
					uint32_t length;
					uint32_t capacity;
				} «typeGenerator.code(context, type)»;
			''').addHeader('inttypes.h', true);
		}
	}
	
	override generateHeader() {
		return codeFragmentProvider.create('''
		uint32_t ringbuffer_mask(uint32_t i, uint32_t len);
		uint32_t ringbuffer_increment(uint32_t i, uint32_t len);
		''')
	}
	
	override generateImplementation() {
		return codeFragmentProvider.create('''
			//assumes that you won't be overflowing by more than len
			uint32_t ringbuffer_mask(uint32_t i, uint32_t len) {
				if(i >= len) {
					return i - len;
				}
				return i;
			}
			
			uint32_t ringbuffer_increment(uint32_t i, uint32_t len) {
				return ringbuffer_mask(i + 1, len);
			}
		''')
	}
	
	override generateTypeSpecifier(AbstractType type, EObject context) {
		if(type instanceof TypeConstructorType) {
			codeFragmentProvider.create('''ringbuffer_«typeGenerator.code(context, type.typeArguments.tail.head)»''').addHeader('MitaGeneratedTypes.h', false);	
		}
	}
	
	override generateVariableDeclaration(AbstractType type, EObject context, ValidElementSizeInferenceResult size, CodeFragment varName, Expression initialization, boolean isTopLevel) {
		if(type instanceof TypeConstructorType) {
			if(isTopLevel) {
				if(initialization instanceof NewInstanceExpression) {
					val occurrence = getOccurrence(context);
					return codeFragmentProvider.create('''
						«typeGenerator.code(context, type.typeArguments.tail.head)» data_«varName»_«occurrence»[«size.elementCount»];
						«typeGenerator.code(context, type)» «varName» = {
							.data = data_«varName»_«occurrence»,
							.read = 0,
							.length = 0,
							.capacity = «size.elementCount»
						};
					''')
				}
			}
		}
		return super.generateVariableDeclaration(type, context, size, varName, initialization, isTopLevel);
	}
	
	override generateNewInstance(CodeFragment varName, AbstractType type, NewInstanceExpression expr) {
		if(type instanceof TypeConstructorType) {
			val parent = expr.eContainer;
			val isGlobalVariable = !needsCast(expr);
			if(isGlobalVariable) {
				return codeFragmentProvider.create('''''');
			}
			val size = StaticValueInferrer.infer(ExpressionUtils.getArgumentValue(expr.reference as Operation, expr, "size"), []);
			val occurrence = getOccurrence(parent);
			
			return codeFragmentProvider.create('''
				«typeGenerator.code(expr, type.typeArguments.tail.head)» data_«varName»_«occurrence»[«size»];
				«varName» = («typeGenerator.code(expr, type)») {
					.data = data_«varName»_«occurrence»,
					.read = 0,
					.length = 0,
					.capacity = «size»
				};
			''')
		}
	}
	
	static class PushGenerator extends AbstractFunctionGenerator {
		@Inject
		protected extension StatementGenerator;
		@Inject
		extension GeneratorUtils
		
		override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
			val rbRef = ExpressionUtils.getArgumentValue(functionCall.reference as Operation, functionCall, "self").code;
			val value = ExpressionUtils.getArgumentValue(functionCall.reference as Operation, functionCall, "element").code;
			return generate(rbRef, value, functionCall);
		}
		
		public def generate(IGeneratorNode rbRef, IGeneratorNode value, ElementReferenceExpression ref) {
			return codeFragmentProvider.create('''
				if(«rbRef».length >= «rbRef».capacity) {
					«generateExceptionHandler(ref, "EXCEPTION_INDEXOUTOFBOUNDSEXCEPTION")»
				}
				«rbRef».data[ringbuffer_mask(«rbRef».read + «rbRef».length++, «rbRef».capacity)] = «value»;
			''').addHeader("MitaGeneratedTypes.h", false);
		}
	}
	static class PopGenerator extends AbstractFunctionGenerator {
		@Inject
		protected extension StatementGenerator statementGenerator;
		@Inject
		extension GeneratorUtils
		
		@Inject
		protected GeneratorRegistry registry
		
		@Inject
		protected ElementSizeInferrer sizeInferrer;
		
		override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
			val rbRef = functionCall.arguments.head.value;
			val rbRefCode = rbRef.code;
			val innerType = resultVariable?.type;
			
			return codeFragmentProvider.create('''
				if(«rbRefCode».length == 0) {
					«generateExceptionHandler(functionCall, "EXCEPTION_INDEXOUTOFBOUNDSEXCEPTION")»
				}
				--«rbRefCode».length;
«««				EObject context, CodeFragment tempVarName, CodeWithContext left, AssignmentOperator op, CodeWithContext right, boolean alwaysGenerate
				«statementGenerator.initializationCode(
					functionCall, 
					resultVariable.code, 
					resultVariable, 
					AssignmentOperator.ASSIGN, 
					new CodeWithContext(innerType, Optional.absent, codeFragmentProvider.create('''«rbRefCode».data[«rbRefCode».read]'''), resultVariable.size), 
					true
				)»
				«rbRefCode».read = ringbuffer_increment(«rbRefCode».read, «rbRefCode».capacity);
			''').addHeader("MitaGeneratedTypes.h", false);
		}		
	}
	static class PeekGenerator extends AbstractFunctionGenerator {
		@Inject
		protected extension StatementGenerator statementGenerator;
		@Inject
		extension GeneratorUtils
		
		override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
			val rbRef = functionCall.arguments.head.code;
			return codeFragmentProvider.create('''
				if(«rbRef».length == 0) {
					«generateExceptionHandler(functionCall, "EXCEPTION_INDEXOUTOFBOUNDSEXCEPTION")»
				}
				«IF resultVariable !== null»«resultVariable.code» = «ENDIF»«rbRef».data[«rbRef».read];
			''').addHeader("MitaGeneratedTypes.h", false);
		}		
	}
	static class CountGenerator extends AbstractFunctionGenerator {
		@Inject
		protected extension StatementGenerator statementGenerator;
		
		override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
			val rbRef = functionCall.arguments.head.code;
			return codeFragmentProvider.create('''
				«IF resultVariable !== null»«resultVariable.code» = «ENDIF»«rbRef».length;
			''').addHeader("MitaGeneratedTypes.h", false);
		}		
	}
	static class EmptyGenerator extends AbstractFunctionGenerator {
		@Inject
		protected extension StatementGenerator statementGenerator;
		
		override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
			val rbRef = functionCall.arguments.head.code;
			return codeFragmentProvider.create('''
				«IF resultVariable !== null»«resultVariable.code» = «ENDIF»«rbRef».length == 0;
			''').addHeader("MitaGeneratedTypes.h", false);
		}		
	}
	static class FullGenerator extends AbstractFunctionGenerator {
		@Inject
		protected extension StatementGenerator statementGenerator;
		
		override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
			val rbRef = functionCall.arguments.head.code;
			return codeFragmentProvider.create('''
				«IF resultVariable !== null»«resultVariable.code» = «ENDIF»«rbRef».length == «rbRef».capacity;
			''').addHeader("MitaGeneratedTypes.h", false);
		}		
	}

	
}




