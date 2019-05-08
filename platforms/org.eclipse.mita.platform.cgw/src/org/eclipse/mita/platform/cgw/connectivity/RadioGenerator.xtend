package org.eclipse.mita.platform.cgw.connectivity

import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator

class RadioGenerator extends AbstractSystemResourceGenerator {
	
	override generateSetup() {
		return codeFragmentProvider.create('''''')
	}
	
	override generateEnable() {
		return codeFragmentProvider.create('''''')
	}
	
}