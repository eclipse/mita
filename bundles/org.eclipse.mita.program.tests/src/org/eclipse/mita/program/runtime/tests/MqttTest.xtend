package org.eclipse.mita.program.runtime.tests

import java.nio.file.Paths
import java.time.Instant
import org.junit.Assert
import org.junit.Test

import static extension org.eclipse.mita.base.util.BaseUtils.zip;
import java.util.stream.Collectors

class MqttTest extends AbstractRuntimeTest {
	@Test
	def testMe() {
		val projectPath = setup("epochTimeTest", '''
		package my.pkg;
		
		import platforms.x86;
		
		setup mqtt: MQTT { 
			url = "tcp://localhost:1883";
			clientId = "replace_me";
			var x = topic("foo");
		}
		
		var ctr = 0;
		
		every 1 second {
			mqtt.x.write(`${ctr}`);
			ctr = ctr + 1;
			if(ctr > 10) {
				exit(0);
			}
		}
		
		every mqtt.x.msgReceived(msg) {
			println(msg); 
		}
		
		native unchecked fn exit(status: int16): void header "stdlib.h";
		''').key;
		compileMita(projectPath);
		compileC(projectPath, "all");
		val mosquitto = runAtMost(Paths.get("mosquitto"), 60);
		val executable = projectPath.resolve(Paths.get("src-gen", "build", "app"));
		val lines = runAtMost("LD_LIBRARY_PATH=" + projectPath.resolve(Paths.get("lib")), executable, 60);
		val expectedLines = (0..9).map[it.toString];
		lines.collect(Collectors.toList).zip(expectedLines).forEach[
			Assert.assertEquals(it.key, it.value)
		]
	}
}