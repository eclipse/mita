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

import org.junit.Test
import java.nio.file.Paths
import org.junit.Assert

import static extension org.eclipse.mita.base.util.BaseUtils.zip;
import java.util.stream.Collectors

class StringTest extends AbstractRuntimeTest {
	@Test
	def testMe() {
		val projectPath = setup("stringTest", '''
		package my.pkg;
				
		import platforms.x86;
		
		var x = 0;
		
		every x86.startup {
			println("1");
			let a = "2";
			println(a);
			let b = "3";
			println(`${b}4`);
			// test that last print didn't mutate b
			println(`${b}`);
			var c = "5";
			c += "6";
			println(c); 
			var d = new string<100>();
			d += "7";
			println(d);
			for(var i = 8; i < 12; i++) {
				d += `${i}`;
			}
			println(d);
			exit(0); 
		}
		
		every 1 second {
			// do nothing, this is just to generate time functions
		}
		
		native unchecked fn exit(status: int16): void header "stdlib.h";
		''').key;
		compileMita(projectPath);
		compileC(projectPath, "all");
		val executable = projectPath.resolve(Paths.get("src-gen", "build", "app"));
		val lines = runAtMost(executable, 60);
		val expectedLines = #["1", "2", "34", "3", "56", "7", "7891011"];
		for(l1_l2: lines.collect(Collectors.toList).zip(expectedLines)) {
			println(l1_l2);
			println(l1_l2.key.trim + ", " + l1_l2.value.trim);
			Assert.assertEquals(l1_l2.key, l1_l2.value);
		}
	}
}