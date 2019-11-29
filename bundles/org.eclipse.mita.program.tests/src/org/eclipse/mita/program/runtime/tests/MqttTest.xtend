package org.eclipse.mita.program.runtime.tests

import java.nio.file.Paths
import java.time.Instant
import org.junit.Assert
import org.junit.Test

import static extension org.eclipse.mita.base.util.BaseUtils.zip;
import java.util.stream.Collectors
import java.util.concurrent.TimeUnit

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
		val Runtime rt = Runtime.getRuntime();
		val pahoLibUrl = "https://www.eclipse.org/downloads/download.php?file=/paho/1.4/Eclipse-Paho-MQTT-C-1.3.1-Linux.tar.gz";
		val downloadLocation = "/tmp/paho.tar.gz";
				
		val wgetCommand = rt.exec(#["wget", pahoLibUrl, "-O", downloadLocation]);
		wgetCommand.waitFor(60, TimeUnit.SECONDS);
		
		val extractCommand = rt.exec(#["tar", "xvzf", downloadLocation, "-C", projectPath.toString, "--strip-components=1"]);
		extractCommand.waitFor(60, TimeUnit.SECONDS);

		compileMita(projectPath);
		compileC(projectPath, "all");
		val mosquitto = rt.exec("mosquitto");
		val executable = projectPath.resolve(Paths.get("src-gen", "build", "app"));
		val lines = runAtMost(executable, #["LD_LIBRARY_PATH=" + projectPath.resolve(Paths.get("lib"))], 60);
		mosquitto.destroyForcibly;
		val expectedLines = (0..9).map[it.toString];
		lines.collect(Collectors.toList).zip(expectedLines).forEach[
			Assert.assertEquals(it.key, it.value)
		]
	}
}