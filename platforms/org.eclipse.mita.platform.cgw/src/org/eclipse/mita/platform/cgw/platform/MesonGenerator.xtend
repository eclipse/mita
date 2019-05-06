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

import java.util.List
import org.eclipse.mita.program.generator.CompilationContext
import org.eclipse.mita.program.generator.PlatformMesonGenerator

class MesonGenerator extends PlatformMesonGenerator {
	override generateMeson(CompilationContext context, List<String> sourceFiles) {
		return codeFragmentProvider.create('''
			# Define project name
			project('application', 'c')
			
			# Get board
			subdir('kiso/boards/CommonGateway')
			
			# Get 3rd party libraries
			subdir('kiso/thirdparty/freertos')
			subdir('kiso/thirdparty/stm32cubel4')
			subdir('kiso/thirdparty/bstlib')
			subdir('kiso/thirdparty/SeggerRTT')
			
			# Get kiso libraries
			subdir('kiso/core/essentials')
			subdir('kiso/core/utils')
			#subdir('kiso/core/connectivity/cellular')
			
			
			# Get sources
			application_files = [«FOR sourceFile: sourceFiles.filter[it.endsWith(".c")] SEPARATOR(", ")»'«sourceFile»'«ENDFOR»]
			
			# Define application build and its dependencies
			exe = executable('Application.out', 
			  application_files,
			  dependencies : [bsp_lib_dep, freertos_lib_dep, stm32cubel4_lib_dep, essentials_lib_dep, utils_lib_dep, bst_lib_dep, seggerrtt_lib_dep],
			  include_directories: ['.', 'base'],
			  install : true)
			
			run_target(
				'hex', 
				command: [
					meson.get_cross_property('objcopy'),
					meson.get_cross_property('objcopy_args'),
					exe.full_path(), exe.full_path() + '.bin'], 
				depends: exe)
	''')
	}
	
	override getCrossFile() {
		return "kiso/boards/CommonGateway/meson_config_stm32l4_gcc8.ini";
	}
	
	override getConfigureArgs() {
		return "-Db_pch=false -Db_staticpic=false"
	}
	
}