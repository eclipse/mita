package org.eclipse.mita.program.generator

import com.google.inject.Inject
import java.util.List
import org.eclipse.xtext.generator.IFileSystemAccess2

abstract class PlatformMesonGenerator extends PlatformBuildSystemGenerator {
	
	@Inject 
	protected CodeFragmentProvider codeFragmentProvider;
	
	@Inject
	protected ProgramDslTraceExtensions traceExtensions;
	
	def CodeFragment generateMeson(CompilationContext context, List<String> sourceFiles)
	
	override void generateFiles(IFileSystemAccess2 fsa, CompilationContext context, List<String> sourceFiles) {
		val codefragment = generateMeson(context, sourceFiles)
		if(codefragment !== null && codefragment != CodeFragment.EMPTY) {
			var root = CodeFragment.cleanNullChildren(codefragment);
			traceExtensions.generateTracedFile(fsa, 'meson.build', root);		
		}
		val crossFileLocation = crossFile;
		val configureArgs = getConfigureArgs;
		traceExtensions.generateTracedFile(fsa, 'Makefile', codeFragmentProvider.create('''
			all:
				«context.mesonExecutable» debug«IF !crossFileLocation.nullOrEmpty» --cross-file "«crossFile»"«ENDIF»
				«IF !configureArgs.nullOrEmpty»cd debug && «context.mesonExecutable» configure «configureArgs»«ENDIF»
				cd debug && «context.ninjaExecutable» «compileTarget»
		'''))
	}
	
	def String getCrossFile();
	
	def String getConfigureArgs();
	
	def String getCompileTarget();
	
	def String getMesonExecutable(CompilationContext context) {
		return "meson";
	}
	def String getNinjaExecutable(CompilationContext context) {
		return "ninja";
	}
	
}