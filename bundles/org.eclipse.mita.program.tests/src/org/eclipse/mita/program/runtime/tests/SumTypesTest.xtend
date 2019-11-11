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

class SumTypesTest extends AbstractRuntimeTest {
	@Test
	def testMe() {
		val projectPath = setup("sumTypesTest", '''
			package my.pkg;
			
			import platforms.x86;
			
			struct vec2d_t {
			    var x: int32;
			    var y: int32;
			}
			
			alt anyVec { 
				  vec0d /* singleton */ 
				| vec1d: int32 
				| vec2d: vec2d_t 
				| vec3d: {x: int32, y: int32, z: int32} 
				| vec4d: int32, int32, int32, int32
			}
					
			fn incVec(a: anyVec) {
				var b = anyVec.vec0d();
			    where(a) {
					is(anyVec.vec0d) {
						b = anyVec.vec0d(); 
					} 
					is(anyVec.vec1d -> x) {
					    b = anyVec.vec1d(x + 1);
					} 
					is(anyVec.vec2d -> v) {
					    b = anyVec.vec2d(vec2d_t(x = v.x + 1, y = v.y + 1));
					}
					is(anyVec.vec3d -> x = vec3d.x, y = vec3d.y, z = vec3d.z) {
					    b = anyVec.vec3d(x + 1, y + 1, z + 1);
					}
					is(anyVec.vec4d -> x, y, z, w) {
						b = anyVec.vec4d(x + 1, y + 1, z + 1, w + 1);
					} 
			    } 
			    return b;
			}
			
			fn toString(a: anyVec) {
				where(a) {
					is(anyVec.vec0d) {
						return "v0d()";
					} 
					is(anyVec.vec1d -> x) {
						return `v1d(${x})`;
					} 
					is(anyVec.vec2d -> v) {
					    return `v2d(${v.x}, ${v.y})`;
					}
					is(anyVec.vec3d -> x = vec3d.x, y = vec3d.y, z = vec3d.z) {
					    return `v3d(${x}, ${y}, ${z})`;
					}
					is(anyVec.vec4d -> x, y, z, w) {
						return `v4d(${x}, ${y}, ${z}, ${w})`;
					}
				}
			}
			
			var w0 = anyVec.vec0d();
			var w1 = anyVec.vec1d(11);
			var w2 = anyVec.vec2d(vec2d_t(12, 13));
			var w3 = anyVec.vec3d(14, 15, 16);
			var w4 = anyVec.vec4d(17, 18, 19, 20);
			
			every x86.startup {
				var v0 = anyVec.vec0d();
				var v1 = anyVec.vec1d(1);
				var v2 = anyVec.vec2d(vec2d_t(2, 3));
				var v3 = anyVec.vec3d(4, 5, 6);
				var v4 = anyVec.vec4d(7, 8, 9, 10);
				println(v0.incVec().toString());
				println(v1.incVec().toString());
				println(v2.incVec().toString());
				println(v3.incVec().toString());
				println(v4.incVec().toString());
				
				println(w0.incVec().toString());
				println(w1.incVec().toString());
				println(w2.incVec().toString());
				println(w3.incVec().toString());
				println(w4.incVec().toString());
				exit(0);  
			} 

			every 100 milliseconds {
				
			}
			
			native unchecked fn exit(status: int16): void header "stdlib.h";
		''').key;
		compileMita(projectPath);
		compileC(projectPath, "all");
		val executable = projectPath.resolve(Paths.get("src-gen", "build", "app"));
		val lines = runAtMost(executable, 60);
		val expectedLines = #[
			"v0d()",
			"v1d(2)",
			"v2d(3, 4)",
			"v3d(5, 6, 7)",
			"v4d(8, 9, 10, 11)",
			"v0d()",
			"v1d(12)",
			"v2d(13, 14)",
			"v3d(15, 16, 17)",
			"v4d(18, 19, 20, 21)"
		]
		for(l1_l2: lines.collect(Collectors.toList).zip(expectedLines)) {
			Assert.assertEquals(l1_l2.key, l1_l2.value);
		}
	}
}