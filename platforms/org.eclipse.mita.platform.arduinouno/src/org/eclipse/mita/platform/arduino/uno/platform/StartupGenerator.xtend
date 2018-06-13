/********************************************************************************
 * Copyright (c) 2018 itemis AG.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    itemis AG - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/
 
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
		''').setPreamble(
			'''
			«FOR handler : context.allEventHandlers»
			extern void set«handler.handlerName»_flag();
			«ENDFOR»
			'''
		)
	}

}
