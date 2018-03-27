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

package org.eclipse.mita.program.generator.tests

import org.eclipse.mita.program.generator.tests.AbstractGeneratorTest
import org.junit.Test

class SumTypesTest extends AbstractGeneratorTest {
	/* Template
	@Test
	def testSumType() {
		val ast = generateAndParseApplication('''
		package test;
		
		''');
		ast.assertNoCompileErrors();
	}
	 */
	
	@Test
	def testSumTypeDefinition() {
		val ast = generateAndParseApplication('''
			package test;
			import platforms.unittest;
			
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
		''');
		ast.assertNoCompileErrors();
	}
	
	@Test
	def testSumTypeWhereIs() {
		val ast = generateAndParseApplication('''
			package test;
			import platforms.unittest;
			
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
			
			fn incVecs(a: anyVec) {
			    var b: anyVec;
			    where(a) {
			    	is(anyVec.vec0d) {
			    	} 
			    	   is(x: anyVec.vec1d) {
			    	   } 
			    	   is(anyVec.vec2d -> x = vec2d.x, y = vec2d.y) {
			    	   }
			    	   is(anyVec.vec3d -> x = vec3d.x, y = vec3d.y, z = vec3d.z) {
			    	   }
			    	   is(anyVec.vec1d -> x) {
					}
					      is(anyVec.vec2d -> x, y) {
					      }
					      is(anyVec.vec3d -> x, y, z) {
					      }
					      is(anyVec.vec4d -> x, y, z, w) {
					      }
					      isother {
					      }
					  } 
					  return b;
			}
		''');
		ast.assertNoCompileErrors();
	}
	
	@Test
	def testSumTypesVectorExample() {
		val ast = generateAndParseApplication(
			'''
				package test;
				import platforms.unittest;
				
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
				
				exception UnknownTypeException;
				
				fn incVecs(a: anyVec) {
				    var b: anyVec;
				    where(a) {
				    	is(anyVec.vec0d) {
				    		b = anyVec.vec0d(); 
				    	} 
				    	   is(anyVec.vec1d -> x) {
				    	       b = anyVec.vec1d(x + 1);
				    	   } 
				    	   is(anyVec.vec2d -> x = vec2d.x, y = vec2d.y) {
				    	       b = anyVec.vec2d(x = x + 1, y = y + 1);
				    	   }
				    	   is(anyVec.vec3d -> x = vec3d.x, y = vec3d.y, z = vec3d.z) {
				    	       b = anyVec.vec3d(x + 1, y + 1, z + 1);
				    	   }
				    	   is(anyVec.vec4d -> x, y, z, w) {
				    	   	b = anyVec.vec4d(x + 1, y + 1, z + 1, w + 1);
				    	   } 
				    	   isother {
				    	       throw UnknownTypeException;
				    	   } 
				    } 
				    return b;
				}
			'''	
		);
		ast.assertNoCompileErrors();
	}
}
