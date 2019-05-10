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
		traceExtensions.generateTracedFile(fsa, 'Makefile', codeFragmentProvider.create('''
			all:
				«context.mesonExecutable» debug«IF !crossFileLocation.nullOrEmpty» --cross-file "«crossFile»"«ENDIF»
				cd debug && «context.mesonExecutable» configure «getConfigureArgs»
				cd debug && «context.ninjaExecutable» hex
		'''))
	}
	
	def String getCrossFile();
	
	def String getConfigureArgs();
	
	def String getMesonExecutable(CompilationContext context) {
		return "meson";
	}
	def String getNinjaExecutable(CompilationContext context) {
		return "ninja";
	}
	
}