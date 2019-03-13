package org.eclipse.mita.program.generator

import com.google.inject.Inject
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.emf.ecore.EObject

class RingbufferGenerator {
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	@Inject
	protected TypeGenerator typeGenerator;
	
	def generateHeader(TypeSpecifier innerType) {
		codeFragmentProvider.create('''
			typedef struct {
				«typeGenerator.code(innerType)»* data;
				uint32_t read;
				uint32_t length;
				uint32_t capacity;
			} «typeGenerator.code(innerType)»;
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
	def generateTypeSpecifier(TypeSpecifier type) {
		codeFragmentProvider.create('''ringbuffer_«typeGenerator.code(type.typeArguments.head)»''').addHeader('MitaGeneratedTypes.h', false);
	}
}