/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *    itemis AG - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/
  
package org.eclipse.mita.platform.x86.platform

import org.eclipse.mita.program.generator.IPlatformTimeGenerator
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import com.google.inject.Inject
import org.eclipse.mita.program.TimeIntervalEvent
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.mita.program.generator.IPlatformEventLoopGenerator
import org.eclipse.mita.program.generator.GeneratorUtils

class TimeGenerator implements IPlatformTimeGenerator {

	@Inject
	protected extension CodeFragmentProvider codeFragmentProvider

	@Inject
	protected IPlatformEventLoopGenerator eventLoopGenerator

	@Inject
	protected extension GeneratorUtils
	
	override generateTimeEnable(CompilationContext context, EventHandlerDeclaration handler) {
		val period = ModelUtils.getIntervalInMilliseconds(handler.event as TimeIntervalEvent);
		return codeFragmentProvider.create('''lastTick«period.toString.toFirstUpper» = getTime();''')
			.setPreamble('''
			#ifdef __linux__
			#include <unistd.h>
			#include <time.h>
			#include <bits/time.h>
			void sleepMs(uint32_t ms) {
				usleep(ms * 1000);
			}
			int32_t getTime(void) {
				struct timespec ts;
				clock_gettime(CLOCK_MONOTONIC, &ts);
				return 1000*ts.tv_sec + ts.tv_nsec/1000000; 
			}
			#endif
			#ifdef _WIN32
			#include <windows.h>
			void sleepMs(uint32_t ms) {
				Sleep(ms);
			}
			int32_t getTime() {
				return clock();
			}
			#endif
			''')
			.addHeader('time.h', true)
			.addHeader('MitaExceptions.h', false)
			.addHeader('MitaEvents.h', false);
	}

	override generateTimeGoLive(CompilationContext context) {
		return CodeFragment.EMPTY
	}

	override generateTimeSetup(CompilationContext context) {
		
		return codeFragmentProvider.create('''
			return 0;
		''')
	}
	
	override generateAdditionalHeaderContent(CompilationContext context) {
		return codeFragmentProvider.create('''
		#ifdef __linux__
		#include <unistd.h>
		#include <time.h>
		#include <bits/time.h>
		void sleepMs(uint32_t ms);
		int32_t getTime(void);
		#endif
		#ifdef _WIN32
		#include <windows.h>
		void sleepMs(uint32_t ms);
		int32_t getTime();
		#endif
		''')
	}
	
}
