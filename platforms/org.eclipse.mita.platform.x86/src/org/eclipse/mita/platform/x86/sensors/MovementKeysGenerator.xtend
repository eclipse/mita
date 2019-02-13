package org.eclipse.mita.platform.x86.sensors

import com.google.inject.Inject
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.xtext.EcoreUtil2

class MovementKeysGenerator extends AbstractSystemResourceGenerator {
	
	@Inject
	GeneratorUtils generatorUtils;
	
	override generateSetup() {
		return codeFragmentProvider.create('''''')
		.setPreamble('''
		#ifdef __linux__
		//TODO
		#endif
		#ifdef _WIN32
		#include <windows.h>
		bool isPressed(uint8_t key) {
			return GetKeyState(key) & 0x8000;
		}
		#endif

		''')
		.addHeader("stdbool.h", true)
	}
	
	override generateEnable() {
		return CodeFragment.EMPTY;
	}
	
	override generateAccessPreparationFor(ModalityAccessPreparation accessPreparation) {
		val varName = generatorUtils.getUniqueIdentifier(accessPreparation);
		val needCast = EcoreUtil2.getContainerOfType(accessPreparation, ProgramBlock) !== null;
		
		return codeFragmentProvider.create('''KeyState «varName» = «IF needCast»(KeyState) «ENDIF»{
			.UP = isPressed('W'),
			.LEFT = isPressed('A'),
			.DOWN = isPressed('S'),
			.RIGHT = isPressed('D')
		};''')
	}
	
	override generateModalityAccessFor(ModalityAccess modalityAccess) {
		val varName = generatorUtils.getUniqueIdentifier(modalityAccess.preparation);
		
		return codeFragmentProvider.create('''«varName».«modalityAccess.modality.name»''');
	}
	
	override generateAdditionalHeaderContent() {
		return codeFragmentProvider.create('''
		
		bool isPressed(uint8_t key);
		
		typedef struct {
			bool UP;
			bool DOWN;
			bool LEFT;
			bool RIGHT;
		} KeyState;
		''')
		.addHeader("stdbool.h", true)
	}
	
}