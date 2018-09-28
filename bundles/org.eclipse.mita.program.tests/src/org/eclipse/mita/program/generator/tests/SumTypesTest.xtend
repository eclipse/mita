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

import java.util.Map
import org.eclipse.cdt.core.dom.ast.IASTDeclarator
import org.eclipse.cdt.core.dom.ast.IASTEqualsInitializer
import org.eclipse.cdt.core.dom.ast.IASTInitializerList
import org.eclipse.cdt.core.dom.ast.IASTLiteralExpression
import org.eclipse.cdt.core.dom.ast.IASTSimpleDeclaration
import org.eclipse.cdt.core.dom.ast.c.ICASTFieldDesignator
import org.eclipse.cdt.core.dom.ast.c.ICASTTypeIdInitializerExpression
import org.junit.Assert
import org.junit.Test
import org.eclipse.cdt.core.dom.ast.c.ICASTDesignatedInitializer

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
	def testSumTypeGlobals() {
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
			
			let v1 = anyVec.vec0d();
			let v2 = anyVec.vec1d(1);
			let v3 = anyVec.vec2d(2, 3);
			let v4 = anyVec.vec3d(4, 5, 6);
			let v5 = anyVec.vec4d(7, 8, 9, 10);
		''');
		ast.assertNoCompileErrors();
	}
	
	@Test
	def void testSumTypeNamedParameters() {
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
		
		let c1 = anyVec.vec2d(y = 1, x = 0);
		let c2 = anyVec.vec3d(z = 2, y = 1, x = 0);
		''')
		ast.assertNoCompileErrors();
		val ast2 = ast.value;
		val decls = ast2.declarations
		val varDecls = decls.filter(IASTSimpleDeclaration).map[it.declarators.head].toList
		val c1 = varDecls.findFirst[it.name.toString == "c1"]
		val c2 = varDecls.findFirst[it.name.toString == "c2"]
		
		verifyInit(c1, #{"x" -> "0", "y" -> "1"});
		verifyInit(c2, #{"x" -> "0", "y" -> "1", "z" -> "2"});
	}
	
	def void verifyInit(IASTDeclarator varDecl, Map<String, String> inits) {
		val init1 = varDecl.initializer as IASTEqualsInitializer
		val init2 = init1.initializerClause as IASTInitializerList
		val init3 = init2.clauses.filter(ICASTDesignatedInitializer).findFirst[member | 
			member.designators.findFirst[
				val accessor = it as ICASTFieldDesignator;
				accessor.name.toString == "data"
			] !== null
		]
		val init4 = init3.operand as ICASTTypeIdInitializerExpression;
		val init5 = init4.initializer as IASTInitializerList;
		val init6 = init5.clauses.filter(ICASTDesignatedInitializer)
		init6.forEach[init|  
			val nameDesign = init.designators.head as ICASTFieldDesignator
			val name = nameDesign.name.toString
			val valueExpr = init.operand as IASTLiteralExpression
			val value = String.copyValueOf(valueExpr.value)
			val ok = inits.get(name) == value
			if(!ok) {
				Assert.fail("Didn't do named parameters properly:\n" + name + " = " + value + "\nExpected:\n" + name + " = " + inits.get(name))
			}
		]
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
			    var b = anyVec.vec0d();
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
					var b = anyVec.vec0d();
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
	
	@Test
	def testSumTypeAnonymus() {
		val ast = generateAndParseApplication(
			'''
				package test;
				import platforms.unittest;
				alt foo { bar: int32 }
				let foobar = foo.bar(1);
			'''
		);
		ast.assertNoCompileErrors();
	}
}
