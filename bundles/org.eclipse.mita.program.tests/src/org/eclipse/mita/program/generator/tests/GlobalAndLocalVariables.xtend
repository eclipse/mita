package org.eclipse.mita.program.generator.tests

import org.junit.Test

class GlobalAndLocalVariables  extends AbstractGeneratorTest {
	
	@Test
	def testGlobalVariables() {
		val ast = generateAndParseApplication('''
		package test;
		import platforms.unittest;
		
		fn foo(): uint32 {
			return 0;
		}
		fn inc(x: uint32): uint32 {
			return x + 1;
		}
		
		struct TS {
			var x: int32;
		}
		alt TA {
			a0: int32 | a1: int32, int32 | a2 : { x: int32 } | a3: TS | a4: {x: TS}
		}
		
		let a = 10;
		let b = foo();
		let c = inc(b);
		let d = TS(0);
		let e = TA.a0(0);
		let f = TA.a1(0, 1);
		let g = TA.a2(0);
		let h = TA.a3(0);  
		let i = TA.a4(TS(0));
				
		every 100 milliseconds {
			let a = 10;
			let b = foo();
			let c = inc(b);
			let d = TS(0);
			let e = TA.a0(0);
			let f = TA.a1(0, 1);
			let g = TA.a2(0);
			let h = TA.a3(0);
			let i = TA.a4(TS(0));
		}
		
		''');
		ast.assertNoCompileErrors();
	}
}