package org.eclipse.mita.platform.arduino.uno.buses

import com.google.inject.Inject
import org.eclipse.mita.program.generator.AbstractSystemResourceGenerator
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CodeFragment

class GPIOGenerator extends AbstractSystemResourceGenerator{
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider	
	
	override generateSetup() {
		return CodeFragment.EMPTY;
	}
	
	override generateEnable() {
		return CodeFragment.EMPTY;
	}
	
}