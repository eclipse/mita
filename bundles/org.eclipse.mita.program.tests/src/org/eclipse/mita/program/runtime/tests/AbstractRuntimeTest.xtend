package org.eclipse.mita.program.runtime.tests

import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.nio.file.Files
import java.nio.file.Path
import java.util.Map
import java.util.concurrent.TimeUnit
import java.util.stream.Stream
import java.lang.ProcessBuilder.Redirect
import java.util.List
import java.nio.file.Paths

class AbstractRuntimeTest {
	/**
	 * Creates a temp folder with name *name* and file application.mita with content *mitaCode*, and returns both the folder and file path.
	 */
	def Pair<Path, Path> setup(String name, String mitaCode) {
		val project = Files.createTempDirectory(name);
		val mitaFile = Files.createFile(project.resolve("application.mita"));
		Files.write(mitaFile, mitaCode.getBytes("UTF-8"));
		return project -> mitaFile;
	}
	
	/**
	 * Requires environment variables to be set (or the correct folder structure which is here as a hint!)
	 * They are:
	 * - "java", path to a jre java binary or java in the "PATH" environment variable
	 * - "make", path to the make binary or java in the "PATH" environment variable
	 * - "MitaCLI", path to a jar file containing the compiler
	 * - "x86platform", path to the x86 platform
	 * - "stdlib", path to the jar containing the stdlib
	 */
	def void compileMita(Path projectFolder) {
		val Map<String, String> env = System.getenv();
		val compilerJar = env.getOrDefault("MitaCLI", "org.eclipse.mita.cli.jar");
		val x86platformJar = env.getOrDefault("x86platform", "org.eclipse.mita.repository/target/plugins/org.eclipse.mita.platform.x86_0.1.0.jar");
		val stdlibJar = env.getOrDefault("stdlib", "org.eclipse.mita.repository/target/plugins/org.eclipse.mita.library.stdlib_0.1.0.jar");
		val javaExec = env.getOrDefault("java", "java");
		val ps = File.pathSeparatorChar;
		
		val cpEntries = #[compilerJar, x86platformJar];
		
		cpEntries.forEach[
			if(!Files.exists(Paths.get(it))) {
				System.err.println("Not found: " + it);
			}
		]
		
		val List<String> command = #[javaExec, "-cp", '''«cpEntries.join(ps.toString)»''', "-jar", compilerJar, "compile", "-p", projectFolder.toString];
		println("compiling mita project...");
		println(command.join(", "));
		println("");
		
		val ProcessBuilder builder = new ProcessBuilder(command);
		builder.redirectOutput(Redirect.INHERIT);
		builder.redirectError(Redirect.INHERIT);
		val Process pr = builder.start(); // may throw IOException
		pr.waitFor();
	}
	
	def void compileC(Path projectFolder, String target) {
		val Map<String, String> env = System.getenv();
		
		val make = env.getOrDefault("make", "make");
		
		val command = #[make, "-C", projectFolder.resolve("src-gen").toString, target];
		println("compiling C project...");
		println(command.join(", "));
		println("");
		
		val ProcessBuilder builder = new ProcessBuilder(command);
		builder.redirectOutput(Redirect.INHERIT);
		builder.redirectError(Redirect.INHERIT);
		val Process pr = builder.start(); // may throw IOException
		pr.waitFor;
	}
	
	def Stream<String> runAtMost(Path pathToExecutable, int timeInSeconds) {
		println("running exe...");
		println(pathToExecutable);
		println("");
		val Runtime rt = Runtime.getRuntime();
		val Process pr = rt.exec(pathToExecutable.toString);
		val output = new BufferedReader(new InputStreamReader(pr.inputStream));
		pr.waitFor(timeInSeconds, TimeUnit.SECONDS);
		if(pr.alive) {
			pr.destroy();
			pr.waitFor(1, TimeUnit.SECONDS);
		}
		if(pr.alive) {
			pr.destroyForcibly();
		}
		return output.lines;
	}
}