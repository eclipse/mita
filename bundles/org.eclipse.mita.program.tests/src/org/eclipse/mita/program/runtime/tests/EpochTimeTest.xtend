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

import org.junit.Test
import java.nio.file.Paths
import org.junit.Assert
import java.time.Instant

class EpochTimeTest extends AbstractRuntimeTest {
	@Test
	def testMe() {
		val projectPath = setup("epochTimeTest", '''
		package my.pkg;
		
		import platforms.x86;
		
		var x = 0;
		
		every x86.startup(time) {
			println(`${time}`);
		}
		
		every 1 seconds {
			exit(0);
		}
		
		native unchecked fn exit(status: int16): void header "stdlib.h";
		''').key;
		compileMita(projectPath);
		compileC(projectPath, "all");
		val executable = projectPath.resolve(Paths.get("src-gen", "build", "app"));
		val lines = runAtMost(executable, 60);
		val lastLine = lines.iterator.last;
		val timeFromApp = Integer.parseInt(lastLine).intValue;
		val timeFromJava = Instant.now().toEpochMilli() as int;
		println('''java: «timeFromJava», testling: «timeFromApp»''')
		// time difference should be less than 2s
		Assert.assertTrue(Math.abs(timeFromJava - timeFromApp) < 2000);
	}
}