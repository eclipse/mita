package org.eclipse.mita.program.generator

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.xtext.generator.trace.node.IGeneratorNode

class BuiltinRingbufferGenerator {
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	@Inject
	protected TypeGenerator typeGenerator;
	@Inject
	protected extension GeneratorUtils
	
	def generateHeader(EObject context, AbstractType innerType) {
		codeFragmentProvider.create('''
			typedef struct {
				«typeGenerator.code(context, innerType)»* data;
				uint32_t read;
				uint32_t length;
				uint32_t capacity;
			} «typeGenerator.code(context, innerType)»;
		''').addHeader('inttypes.h', true);
	}
	
	def generateHeader() {
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
	def generateTypeSpecifier(EObject context, AbstractType innerType) {
		codeFragmentProvider.create('''ringbuffer_«typeGenerator.code(context, innerType)»''').addHeader('MitaGeneratedTypes.h', false);
	}
	
	def generateVariableDeclaration(EObject context, AbstractType innerType, String varName, int elementCount, boolean globalDeclaration, String suffixForBuffer) {
		
		if(globalDeclaration) {
			// create buffer, too
			return codeFragmentProvider.create('''
				«typeGenerator.code(context, innerType)» data_«varName»_«suffixForBuffer»[«elementCount»];
				«generateTypeSpecifier(context, innerType)» «varName» = {
					.data = data_«varName»_«suffixForBuffer»,
					.read = 0,
					.length = 0,
					.capacity = «elementCount»
				};
			''')
		}
		
		return codeFragmentProvider.create('''
			«generateTypeSpecifier(context, innerType)» «varName»;
		''')
	}
	
	// context: will be used to determine if exception is returned or breaked.
	// if context is null: return exception.
	def generatePopStatements(EObject context, String rbName, IGeneratorNode resultVariable) {
		return codeFragmentProvider.create('''
			if(«rbName».length == 0) {
				«generateExceptionHandler(context, "EXCEPTION_INDEXOUTOFBOUNDSEXCEPTION")»
			}
			--«rbName».length;
			«IF resultVariable !== null»«resultVariable» = «rbName».data[«rbName».read];«ENDIF»
			«rbName».read = ringbuffer_increment(«rbName».read, «rbName».capacity);
		''').addHeader("MitaGeneratedTypes.h", false);
	}
}



