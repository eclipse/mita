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

class ReferencesTest extends AbstractRuntimeTest {
	@Test
	def testMe() {
		val projectPath = setup("referencesTest", '''
			package my.pkg;
			import platforms.x86;
			
			struct v2d {
				var x: int32;
				var y: int32;
			}
			
			alt anyVec {
				vec0d | vec1d: int32 | vec2d: v2d
			}
			
			every x86.startup {
				let x1 = true;
				let x2: int32 = 1;
				let x3 = v2d(0, 1);
				let x4: anyVec = .vec1d(1);
				let x5: anyVec = .vec2d(v2d(0,1));
				let x6 = "foobar";
				let x7: array<int32, ?> = [1,2,3,4];
				printRef(&x1);
				printRef(&x2);
				printRef(&x3);
				printRef(&x4);
				printRef(&x5);
				printRef(&x6);
				printRef(&x7);
				
				exit(0);
			}
			
			fn printRef(x: &bool) {
				println(`${*x}`);
			}
			
			fn printRef(x: &int32) {
				println(`${*x}`); 
			}
			 
			fn printRef(x: &v2d) {
				println(`v2d(${(*x).x}, ${(*x).y})`);
			}

			fn printRef(a: &anyVec) {
				where(*a) { 
					is(anyVec.vec0d) {
						println("v0d()");
					} 
					is(anyVec.vec1d -> x) {
						println(`v1d(${x})`);
					} 
					is(anyVec.vec2d -> v) {
					    printRef(&v);
					}
				}
			} 
			
			fn printRef(x: &string<?>) {
				println(`${*x}`);
			}
			
			fn printRef(x: &array<int32, ?>) {
				for(var i = 0; i < (*x).length(); i++) {
					print(`${(*x)[i]}`);
				}
				println("");
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
		val expectedLines = #["1", "1", "v2d(0, 1)", "v1d(1)", "v2d(0, 1)", "foobar", "1234"];
		for(l1_l2: lines.collect(Collectors.toList).zip(expectedLines)) {
			Assert.assertEquals(l1_l2.key.trim, l1_l2.value.trim);
		}
	}
}