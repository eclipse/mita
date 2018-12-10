package org.eclipse.mita.program.tests.runtime

import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.nio.file.Files
import java.nio.file.Path
import java.util.Map
import java.util.concurrent.TimeUnit
import java.util.stream.Stream

class AbstractRuntimeTest {
	/**
	 * Creates a temp folder with name *name* and file application.mita with content *mitaCode*, and returns both the folder and file path.
	 */
	def Pair<Path, Path> setup(String name, String mitaCode) {
		val project = Files.createTempDirectory(name);
		val mitaFile = Files.createTempFile(project, "application", "mita");
		Files.write(mitaFile, mitaCode.getBytes("UTF-8"));
		return project -> mitaFile;
	}
	
	/**
	 * Requires environment variables to be set (or the correct folder structure which is here as a hint!)
	 */
	def void compileMita(Path projectFolder) {
		val Map<String, String> env = System.getenv();
		val compilerJar = env.getOrDefault("MitaCLI", "org.eclipse.mita.cli.jar");
		val pluginsPath = env.getOrDefault("plugins", "org.eclipse.mita.repository/target/plugins/");
		val javaExec = env.getOrDefault("java", "java");
		val ps = File.pathSeparatorChar;
		
		val command = '''«javaExec» -cp «pluginsPath»«ps»«compilerJar» org.eclipse.mita.cli.Main compile -p «projectFolder.toString»''';
		
		val Runtime rt = Runtime.getRuntime();
		val Process pr = rt.exec(command);
	}
	
	def void compileC(Path projectFolder, String target) {
		val Map<String, String> env = System.getenv();
		
		val make = env.getOrDefault("make", "make");
		
		val command = '''«make» -C «projectFolder.toString» «target»''';
		
		val Runtime rt = Runtime.getRuntime();
		val Process pr = rt.exec(command);
	}
	
	def Stream<String> runAtMost(Path pathToExecutable, int timeInSeconds) {
		val Runtime rt = Runtime.getRuntime();
		val Process pr = rt.exec(pathToExecutable.toString);
		val output = new BufferedReader(new InputStreamReader(pr.inputStream));
		pr.waitFor(timeInSeconds, TimeUnit.SECONDS);
		return output.lines;
	}
}