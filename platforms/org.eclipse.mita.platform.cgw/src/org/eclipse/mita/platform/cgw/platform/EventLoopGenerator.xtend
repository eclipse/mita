/********************************************************************************
 * Copyright (c) 2019 Robert Bosch GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/
 
package org.eclipse.mita.platform.cgw.platform

import com.google.inject.Inject
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.generator.CodeFragment
import org.eclipse.mita.program.generator.CodeFragmentProvider
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.IPlatformEventLoopGenerator
import org.eclipse.mita.program.generator.StatementGenerator
import org.eclipse.mita.program.inferrer.StaticValueInferrer

class EventLoopGenerator implements IPlatformEventLoopGenerator {

	@Inject
	protected CodeFragmentProvider codeFragmentProvider;
	@Inject
	protected StatementGenerator statementGenerator;
	@Inject
	protected extension GeneratorUtils generatorUtils;
	
	def generateEventloopInject(String functionName, String userParam1, String userParam2) {
		return codeFragmentProvider.create('''CmdProcessor_Enqueue(&Mita_EventQueue, «functionName», «userParam1», «userParam2»);''')
			.addHeader('BCDS_CmdProcessor.h', true);
	}
	
	def generateEventloopInjectFromIsr(String functionName, String userParam1, String userParam2) {
		return codeFragmentProvider.create('''CmdProcessor_EnqueueFromIsr(&Mita_EventQueue, «functionName», «userParam1», «userParam2»);''')
			.addHeader('BCDS_CmdProcessor.h', true);
	}
	
	def generateEventloopInject(String functionName) {
		return generateEventloopInject(functionName, '''NULL''', '''0''');
	}
	
	override generateEventLoopInject(CompilationContext context, String functionName) {
		return generateEventloopInject(functionName);
	}
	
	override generateEventLoopStart(CompilationContext context) {
		return codeFragmentProvider.create('''BSP_BoardDelay(0);''')
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
	
	override generateSetupPreamble(CompilationContext context) {
		val platformSetup = context.allUnits.flatMap[it.setup.toList].findFirst[it.type?.name == "XDK110"];
		if(platformSetup === null) {
			return CodeFragment.EMPTY;	
		}
		val startupDelay = platformSetup.getConfigurationItemValue("startupDelay");
		return codeFragmentProvider.create('''
		«IF startupDelay !== null»
		BSP_Board_Delay(«statementGenerator.code(startupDelay)»);
		«ENDIF»
		''')
		.addHeader("BCDS_BSP_Board.h", true)
		.addHeader("BSP_ExtensionPort.h", true)
	}	
	override generateEnablePreamble(CompilationContext context) {
		return CodeFragment.EMPTY;
	}
	
	override generateEventLoopHandlerEpilogue(CompilationContext context, EventHandlerDeclaration declaration) {
		return CodeFragment.EMPTY;
	}
	
}
