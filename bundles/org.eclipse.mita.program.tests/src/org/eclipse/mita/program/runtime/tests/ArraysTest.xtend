/********************************************************************************
 * Copyright (c) 2018 Bosch Connected Devices and Solutions GmbH.
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

import com.google.common.collect.Streams
import java.nio.file.Paths
import org.junit.Assert
import org.junit.Test

class ArraysTest extends AbstractRuntimeTest {
	@Test
	def testMe() {
		val projectPath = setup("arraysTest", '''
		package my.pkg;
		
		import platforms.x86;
		
		native unchecked fn exit(status: int16): void header "stdlib.h";
		
		every x86.startup {
			let ar = new array<int8, 100>();
			try {
				let a0 = foo0();
				printarray(a0);
			}
			catch(InvalidRangeException) {
				println("error a0");
			}
			try {
				let a2 = foo2();
				printarray(a2);
			}
			catch(InvalidRangeException) {
				println("error a2");
			}
			try {
				let a4 = foo4();
				printarray(a4);
			}
			catch(InvalidRangeException) {
				println("error a4");
			}
			try {
				foo6();
			}
			catch(InvalidRangeException) {
				println("error a6");
			}
		} 
		
		every 1 second {
			exit(0);
		}
		 
		fn printarray(a: array<int8, ?>) {
			print("[");
			for(var i = 0; i < a.length(); i++) {
				print(`${a[i]}`);
				if(i < a.length() - 1) {
					print(", ");
				}
			}
			println("]");
		}
		
		fn foo0() {
			var a: array<int8, ?> = [1,2,3,4];
			a += [5 as int8, 6,7]; 
			a = [10,11,12,13,14,15];
			return a; 
		}
		
		fn foo2() {
			var b: array<int8, ?> = [1,2,3,4];
			var a: array<int8, ?> = b;
			a += b; 
			a = b; 
			return a;
		} 
		
		fn foo4() {
			var a: array<int8, ?> = [1,2,3,4];
			a += [5 as int8, 6,7]; 
			a = [10,11,12,13,14,15];
			return a[1:2]; 
		}
		
		fn foo6() {
			var b: array<int8, ?> = [1,2,3,4];
			var a: array<int8, ?> = b[1:2];
			a += b[1:2];  
			a = b[1:2]; 
		}
		''').key;
		compileMita(projectPath);
		compileC(projectPath, "all");
		val executable = projectPath.resolve(Paths.get("src-gen", "build", "app"));
		val lines = runAtMost(executable, 60);
		val expectations = #["[10, 11, 12, 13, 14, 15]", "[1, 2, 3, 4]", "[11]"];
		Streams.zip(lines, expectations.stream, [s1, s2|
			Assert.assertEquals(s1.trim, s2.trim);
			return null;
		])
		return;
	}
}