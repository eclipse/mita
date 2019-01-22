package org.eclipse.mita.program.runtime.tests

import org.junit.Test
import java.nio.file.Paths
import org.junit.Assert

import static extension org.eclipse.mita.base.util.BaseUtils.zip;
import java.util.stream.Collectors

class StringTest extends AbstractRuntimeTest {
	@Test
	def testMe() {
		val projectPath = setup("helloWorld", '''
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
			var d = new string(100);
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
			Assert.assertEquals(l1_l2.key.trim, l1_l2.value.trim);
		}
	}
}