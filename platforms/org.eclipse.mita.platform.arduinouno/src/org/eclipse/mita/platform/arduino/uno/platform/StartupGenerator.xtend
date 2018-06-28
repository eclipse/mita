package org.eclipse.mita.platform.arduino.uno.platform

import org.eclipse.mita.program.generator.IPlatformStartupGenerator
import org.eclipse.mita.program.generator.CompilationContext
import com.google.inject.Inject
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.GeneratorUtils

class StartupGenerator implements IPlatformStartupGenerator {
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject 
	protected extension GeneratorUtils
	
	override generateMain(CompilationContext context) {
		codeFragmentProvider.create('''
			Mita_initialize();
			Mita_goLive();
			while(1) {
				«FOR handler : context.allEventHandlers»
					if (get«handler.handlerName»_flag() == true){
						set«handler.handlerName»_flag(false);
						«handler.handlerName»();
					}
				«ENDFOR»
			}
			return 0;
		''')
	}

}
