package org.eclipse.mita.library.stdlib

import com.google.inject.Inject
import java.util.Optional
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.util.ExpressionUtils
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.Variance
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.infra.FunctionSizeInferrer
import org.eclipse.mita.base.typesystem.infra.InferenceContext
import org.eclipse.mita.base.typesystem.infra.TypeSizeInferrer
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.generator.AbstractFunctionGenerator
import org.eclipse.mita.program.generator.AbstractTypeGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeWithContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.generator.internal.GeneratorRegistry
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.generator.trace.node.IGeneratorNode

import static extension org.eclipse.mita.library.stdlib.ArrayGenerator.getInferredSize
import org.eclipse.mita.base.types.TypeConstructor
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.base.typesystem.types.TypeVariable

// https://www.snellman.net/blog/archive/2016-12-13-ring-buffers/
class RingbufferGenerator extends AbstractTypeGenerator {
	@Inject
	extension GeneratorUtils
	
	@Inject
	protected StatementGenerator statementGenerator;
	
	static def TypeConstructorType wrapInRingbuffer(StdlibTypeRegistry typeRegistry, EObject context, AbstractType innerType) {
		val ringbufferObj = typeRegistry.getTypeModelObject(context, StdlibTypeRegistry.ringbufferTypeQID);
		val ringbufferTypeInstance = new TypeConstructorType(context, "ringbuffer", #[new AtomicType(ringbufferObj, "ringbuffer") -> Variance.INVARIANT, innerType -> Variance.INVARIANT, new TypeVariable(null, 0) -> Variance.COVARIANT])
		return ringbufferTypeInstance;
	}
	
	
	override CodeFragment generateHeader(EObject context, AbstractType type) {
		codeFragmentProvider.create('''typedef struct «typeGenerator.code(context, type)» «typeGenerator.code(context, type)»;''')
	}
	
	override generateTypeImplementations(EObject context, AbstractType type) {
		if(type instanceof TypeConstructorType) {
			codeFragmentProvider.create('''
				struct «typeGenerator.code(context, type)» {
					«typeGenerator.code(context, type.typeArguments.tail.head)»* data;
					uint32_t read;
					uint32_t length;
					uint32_t capacity;
				};
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
	
	override generateGlobalInitialization(AbstractType type, EObject context, CodeFragment varName, Expression initialization) {
		if(type instanceof TypeConstructorType) {
			val occurrence = getOccurrence(context);
			val bufferName = codeFragmentProvider.create('''data_«varName»_«occurrence»''')
			val size = codeFragmentProvider.create('''«type.inferredSize?.eval»''');
			val dataType = type.typeArguments.get(1);
				
			return codeFragmentProvider.create('''
				«statementGenerator.generateBulkAssignment(
					context, 
					codeFragmentProvider.create('''«varName»_rb'''),
					new CodeWithContext(dataType, Optional.empty, bufferName),
					size
				)»
			''')
		}
	}
	
	override generateVariableDeclaration(AbstractType type, EObject context, CodeFragment varName, Expression initialization, boolean isTopLevel) {	
		if(type instanceof TypeConstructorType) {
			val occurrence = getOccurrence(context);
			val bufferName = codeFragmentProvider.create('''data_«varName»_«occurrence»''')
			val size = codeFragmentProvider.create('''«type.inferredSize?.eval»''');
			val dataType = type.typeArguments.get(1);
				
			return codeFragmentProvider.create('''
				«typeGenerator.code(context, type.typeArguments.tail.head)» «bufferName»[«size»];
				«typeGenerator.code(context, type)» «varName» = «IF !isTopLevel»(«typeGenerator.code(context, type)») «ENDIF»{
					.data = «bufferName»,
					.read = 0,
					.length = 0,
					.capacity = «size»
				};
				«statementGenerator.generateBulkAllocation(
					context, 
					codeFragmentProvider.create('''«varName»_rb'''),
					new CodeWithContext(dataType, Optional.empty, bufferName),
					size,
					isTopLevel
				)»
				«IF !isTopLevel»
				«generateGlobalInitialization(type, context, varName, initialization)»
				«ENDIF»
			''')
		}
	}
	
		override generateBulkAllocation(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, CodeFragment count, boolean isTopLevel) {
		val type = left.type as TypeConstructorType;
		val dataType = type.typeArguments.get(1);
		val size = codeFragmentProvider.create('''«type.inferredSize?.eval»''');
		return codeFragmentProvider.create('''
			«typeGenerator.code(context, type.typeArguments.tail.head)» «cVariablePrefix»_buf[«count»*«size»];
			«statementGenerator.generateBulkAllocation(
				context, 
				codeFragmentProvider.create('''«cVariablePrefix»_array'''),
				new CodeWithContext(dataType, Optional.empty, codeFragmentProvider.create('''«cVariablePrefix»_buf''')),
				codeFragmentProvider.create('''«count»*«size»'''),
				isTopLevel
			)»''').addHeader("stddef.h", true)
	}
	
	override generateBulkAssignment(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, CodeFragment count) {
		val type = left.type as TypeConstructorType;
		val dataType = type.typeArguments.get(1);
		val i = codeFragmentProvider.create('''«cVariablePrefix»_i''');
		val size = codeFragmentProvider.create('''«type.inferredSize?.eval»''');
		return codeFragmentProvider.create('''
		for(size_t «i» = 0; «i» < «count»; ++«i») {
			«left.code»[«i»] = («typeGenerator.code(context, type)») {
				.data = &«cVariablePrefix»_buf[«i»*«size»],
				.length = 0,
				.capacity = «size»
			};
		}
		«statementGenerator.generateBulkAssignment(
			context, 
			codeFragmentProvider.create('''«cVariablePrefix»_array'''),
			new CodeWithContext(dataType, Optional.empty, codeFragmentProvider.create('''«cVariablePrefix»_buf''')),
			codeFragmentProvider.create('''«count»*«size»''')
		)»''').addHeader("stddef.h", true)
	}
	
	override generateBulkCopyStatements(EObject context, CodeFragment i, CodeWithContext left, CodeWithContext right, CodeFragment count) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	static class PushGenerator extends AbstractFunctionGenerator {
		@Inject
		protected extension StatementGenerator;
		@Inject
		extension GeneratorUtils
		
		override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
			val rbRef = ExpressionUtils.getArgumentValue(functionCall.reference as Operation, functionCall, "self");
			val value = ExpressionUtils.getArgumentValue(functionCall.reference as Operation, functionCall, "element").code;
			return generate(functionCall, new CodeWithContext(BaseUtils.getType(rbRef), Optional.empty, codeFragmentProvider.create('''«rbRef.code»''')), value);
		}
		
		def generate(EObject context, CodeWithContext rbRef, IGeneratorNode value) {
			val innerType = (rbRef.type as TypeConstructorType).typeArguments.get(1)
			return codeFragmentProvider.create('''
				if(«rbRef.code».length >= «rbRef.code».capacity) {
					«generateExceptionHandler(context, "EXCEPTION_INDEXOUTOFBOUNDSEXCEPTION")»
				}
				«statementGenerator.initializationCode(
					context, 
					codeFragmentProvider.create(''''''),
					new CodeWithContext(
						innerType, 
						Optional.empty, 
						codeFragmentProvider.create('''«rbRef.code».data[ringbuffer_mask(«rbRef.code».read + «rbRef.code».length, «rbRef.code».capacity)]''')),
					AssignmentOperator.ASSIGN, 
					new CodeWithContext(
						innerType, 
						Optional.empty, 
						codeFragmentProvider.create('''«value»''')
					), 
					true
				)»
				«rbRef.code».length++;
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
		
		
		override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
			val rbRef = functionCall.arguments.head.value;
			val rbRefCode = rbRef.code;
			val innerType = resultVariable?.type;
			
			return codeFragmentProvider.create('''
				if(«rbRefCode».length == 0) {
					«generateExceptionHandler(functionCall, "EXCEPTION_INDEXOUTOFBOUNDSEXCEPTION")»
				}
				--«rbRefCode».length;
				«IF resultVariable !== null»
«««				copy data 
				«statementGenerator.initializationCode(
					functionCall, 
					resultVariable.code, 
					resultVariable, 
					AssignmentOperator.ASSIGN, 
					new CodeWithContext(innerType, Optional.empty, codeFragmentProvider.create('''«rbRefCode».data[«rbRefCode».read]''')), 
					true
				)»
				«ENDIF»
				«rbRefCode».read = ringbuffer_increment(«rbRefCode».read, «rbRefCode».capacity);
			''').addHeader("MitaGeneratedTypes.h", false);
		}		
	}
	static class PopInferrer implements FunctionSizeInferrer {
		
		static def wrapInRingbuffer(InferenceContext c, StdlibTypeRegistry typeRegistry, AbstractType t) {
			val ringbufferTypeObject = typeRegistry.getTypeModelObject(c.obj, StdlibTypeRegistry.ringbufferTypeQID);
			// \T S. ringbuffer<T, S>
			val ringbufferType = c.system.getTypeVariable(ringbufferTypeObject);
			// t0 ~ ringbuffer<t, s>
			val ringbufferInstance = c.system.newTypeVariable(c.obj);
			// t0 instanceof \T S. ringbuffer<T, S> => creates t0 := ringbuffer<t1, t2>
			c.system.addConstraint(new ExplicitInstanceConstraint(ringbufferInstance, ringbufferType, new ValidationIssue('''%s is not instance of %s''', c.obj)));
			// bind sigInst<t> to t0
			c.system.addConstraint(new EqualityConstraint(ringbufferInstance, new TypeConstructorType(c.obj, "ringbuffer", #[new AtomicType(ringbufferTypeObject, "ringbuffer") -> Variance.INVARIANT, t -> Variance.INVARIANT, c.system.newTypeVariable(null) -> Variance.COVARIANT]), new ValidationIssue('''%s is not instance of %s''', c.obj)))
			// return t0 ~ sigInst<t>
			return ringbufferInstance;
		}
		
		@Accessors
		TypeSizeInferrer delegate;
		
		@Inject
		StdlibTypeRegistry typeRegistry;
						
		override createConstraints(InferenceContext c) {
			val funCall = c.obj;
			if(funCall instanceof ElementReferenceExpression) {
				if(funCall.arguments.size > 0) {
					val innerType = c.type;
					c.system.associate(innerType, c.obj);
					val rbType = wrapInRingbuffer(c, typeRegistry, innerType);
					val argument = funCall.arguments.head.value;
					c.system.associate(rbType, argument); 	
				}
			}
		}
		
	}
	static class PeekGenerator extends AbstractFunctionGenerator {
		@Inject
		protected extension StatementGenerator statementGenerator;
		@Inject
		extension GeneratorUtils
		
		override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
			val rbRef = functionCall.arguments.head.code;
			val innerType = resultVariable?.type;
			return codeFragmentProvider.create('''
				if(«rbRef».length == 0) {
					«generateExceptionHandler(functionCall, "EXCEPTION_INDEXOUTOFBOUNDSEXCEPTION")»
				}
				«IF resultVariable !== null»
				«statementGenerator.initializationCode(
					functionCall, 
					resultVariable?.code, 
					resultVariable, 
					AssignmentOperator.ASSIGN, 
					new CodeWithContext(innerType, Optional.empty, codeFragmentProvider.create('''«rbRef».data[«rbRef».read]''')), 
					true
				)»
				«ENDIF»
			''').addHeader("MitaGeneratedTypes.h", false);
		}		
	}
	static class CountGenerator extends AbstractFunctionGenerator {
		@Inject
		protected extension StatementGenerator statementGenerator;
		
		// no need to recurse, empty has type uint32
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
		
		// no need to recurse, empty has type bool
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
		
		// no need to recurse, empty has type bool
		override generate(CodeWithContext resultVariable, ElementReferenceExpression functionCall) {
			val rbRef = functionCall.arguments.head.code;
			return codeFragmentProvider.create('''
				«IF resultVariable !== null»«resultVariable.code» = «ENDIF»«rbRef».length == «rbRef».capacity;
			''').addHeader("MitaGeneratedTypes.h", false);
		}		
	}	
}




