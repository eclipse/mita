/********************************************************************************
 * Copyright (c) 2019 Bosch Connected Devices and Solutions GmbH.
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
 
package org.eclipse.mita.program.runtime.tests

import java.nio.file.Paths
import java.util.stream.Collectors
import org.junit.Assert
import org.junit.Test

import static extension org.eclipse.mita.base.util.BaseUtils.zip

class ControlflowTest extends AbstractRuntimeTest {
	@Test
	def testMe() {
		val projectPath = setup("helloWorld", '''
			package my.pkg;
			
			import platforms.x86;
						
			fn f(): bool {
				print("1");
				return true;
			}
			
			fn g(): bool {
				print("2");
				return false;
			}
			 
			// should print: 12 12 1 11 1 12
			every x86.startup { 
				let a = f();
				let b = g();
				print(" "); 
				if(f() && g()) {   
				} 
				print(" "); 
				if(f() || g()) {  
				} 
				print(" ");
				if(f() && (f() || g())) {
				}
				print(" ");
				let c = f() ? true : g();
				print(" ");
				let d = f() ? g() : false;
				println("");
				
				exit(0);
			}
			
			every 1 second {
			}
			
			native unchecked fn exit(status: int16): void header "stdlib.h";
		''').key;
		compileMita(projectPath);
		compileC(projectPath, "all");
		val executable = projectPath.resolve(Paths.get("src-gen", "build", "app"));
		val lines = runAtMost(executable, 60);
		val expectedLines = #[
			"12 12 1 11 1 12"
		]
		for(l1_l2: lines.collect(Collectors.toList).zip(expectedLines)) {
			Assert.assertEquals(l1_l2.key.trim, l1_l2.value);			
		}
	}
}