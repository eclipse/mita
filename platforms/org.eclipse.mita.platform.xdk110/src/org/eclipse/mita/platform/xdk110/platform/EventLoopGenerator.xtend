/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.platform.xdk110.platform

import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.IPlatformEventLoopGenerator
import com.google.inject.Inject

class EventLoopGenerator implements IPlatformEventLoopGenerator {

	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	public def generateEventloopInject(String functionName, String userParam1, String userParam2) {
		return codeFragmentProvider.create('''CmdProcessor_Enqueue(&Mita_EventQueue, «functionName», «userParam1», «userParam2»);''')
			.addHeader('BCDS_CmdProcessor.h', true);
	}
	
	
	public def generateEventloopInject(String functionName) {
		return generateEventloopInject(functionName, '''NULL''', '''0''');
	}
	
	override generateEventLoopInject(CompilationContext context, String functionName) {
		return generateEventloopInject(functionName);
	}
	
	override generateEventLoopStart(CompilationContext context) {
		return CodeFragment.EMPTY;
//		return CodeFragment.withoutTrace("vTaskStartScheduler();")
//			.addHeader('FreeRTOS.h', true, IncludePath.VERY_HIGH_PRIORITY)
//			.addHeader('task.h', true);
	}
	
	override generateEventHeaderPreamble(CompilationContext context) {
		return codeFragmentProvider.create('''extern CmdProcessor_T Mita_EventQueue;''').addHeader('BCDS_CmdProcessor.h', true);
	}
	
	override generateEventLoopHandlerSignature(CompilationContext context) {
		return codeFragmentProvider.create('''void* userParameter1, uint32_t userParameter2''').addHeader('BCDS_Basics.h', true);
	}
	
	override generateEventLoopHandlerPreamble(CompilationContext context, EventHandlerDeclaration handler) {
		return codeFragmentProvider.create('''
		BCDS_UNUSED(userParameter1);
		BCDS_UNUSED(userParameter2);
		''').addHeader('BCDS_Basics.h', true);
	}
	
}