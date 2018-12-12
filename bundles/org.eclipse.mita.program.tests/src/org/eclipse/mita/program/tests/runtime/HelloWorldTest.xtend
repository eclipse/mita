package org.eclipse.mita.program.tests.runtime

import org.junit.Test
import java.nio.file.Paths
import org.junit.Assert

class HelloWorldTest extends AbstractRuntimeTest {
	@Test
	def testMe() {
		val projectPath = setup("helloWorld", '''
		package my.pkg;
		
		import platforms.x86;
		
		var x = 0;
		
		every x86.startup {
			println("Startup!");
		}
		
		every 1 seconds {
			println(`Hello World! ${x++}`);
			if(x > 5) {
				exit(0);
			}
		}
		
		native unchecked fn exit(status: int16): void header "stdlib.h";
		''').key;
		compileMita(projectPath);
		compileC(projectPath, "all");
		val executable = projectPath.resolve(Paths.get("src-gen", "build", "app"));
		val lines = runAtMost(executable, 60);
		val lastLine = lines.iterator.last;
		Assert.assertEquals(lastLine, "Hello World! 5");
	}
}