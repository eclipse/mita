/********************************************************************************
 * Copyright (c) 2018 TypeFox GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.cli.commands

import com.google.inject.Inject
import com.google.inject.Provider
import java.io.File
import java.net.URL
import java.net.URLClassLoader
import java.nio.file.Files
import java.nio.file.Paths
import java.util.LinkedList
import java.util.jar.JarInputStream
import org.apache.commons.cli.Option
import org.apache.commons.cli.Options
import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.mita.base.scoping.ILibraryProvider
import org.eclipse.mita.cli.loader.StandaloneLibraryProvider
import org.eclipse.mita.program.generator.internal.IGeneratorOnResourceSet
import org.eclipse.xtext.generator.GeneratorContext
import org.eclipse.xtext.generator.IGenerator2
import org.eclipse.xtext.generator.JavaIoFileSystemAccess
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.validation.CheckMode
import org.eclipse.xtext.validation.IResourceValidator
import org.apache.commons.cli.CommandLine

class CompileCommand extends AbstractCommand {
	@Inject
	protected XtextResourceSet resourceSet;
	
	@Inject
	protected ILibraryProvider libraryProvider;

	@Inject
	protected Provider<JavaIoFileSystemAccess> fileSystemAccessProvider;
	
	@Inject
	protected IGenerator2 generator;

	@Inject
	protected IResourceValidator resourceValidator;

	protected String projectPath;

	override getOptions() {
		val result = new Options();
		
		val projectPathOption = new Option('p', 'project-path', true, 'Path to the Mita project');
		projectPathOption.required = true;
		result.addOption(projectPathOption);
		
		result.addOption('o', 'output', true, 'Directory where to generate the output');

		return result;
	}
	
	override init(String commandName, CommandLine commandLine) {
		super.init(commandName, commandLine);
		this.projectPath = commandLine.getOptionValue('project-path');
		
		return true;
	}

	def protected loadResourceSet() {
		if(libraryProvider instanceof StandaloneLibraryProvider) {
			libraryProvider.init(resourceSet);
		}
		resourceSet.addLoadOption(XtextResource.OPTION_RESOLVE_ALL, Boolean.FALSE);
		
		// load libraries
		val allFilesInClasspath = getAllMitaAndPlatformFilesInClasspath().toList;
		for(libraryFile : allFilesInClasspath) {
			println("Loading " + libraryFile);
			resourceSet.getResource(URI.createURI(libraryFile), true);
		}
		EcoreUtil.resolveAll(resourceSet);
		validateResources(resourceSet.resources.filter[ it.URI.toString.endsWith('.platform') ]);
		
		// load project files
		Files.find(Paths.get(this.projectPath), Integer.MAX_VALUE, [filePath, fileAttr|fileAttr.isRegularFile()]).
			filter([x|x.toString.endsWith('.mita')]).forEach([ x |
				val fileUri = URI.createFileURI(x.toFile.toString);
				val resource = resourceSet.getResource(fileUri, true);
				resource.eAdapters.add(new CompileToCAdapter());
			]);
			
		// resolve all
		EcoreUtil.resolveAll(resourceSet);
	}
	
	protected def validateResources(Iterable<Resource> resources) {
		var hasIssues = resources.map[resource|
			// check for issues
			val issues = resourceValidator.validate(resource, CheckMode.ALL, CancelIndicator.NullImpl)
			if (!issues.empty) {
				issues.forEach[ System.err.println(it) ];
				return true;
			} else {
				return false;
			}
		].exists[ it ];

		if(hasIssues) {
			throw new Exception('Errors found in the code. See above.')
		}
	}

	public static def getAllMitaAndPlatformFilesInClasspath() {
		val rootURLs = new LinkedList<URL>();
		var cl = Thread.currentThread().getContextClassLoader();
		while (cl !== null) {
			if (cl instanceof URLClassLoader) {
				rootURLs.addAll(cl.URLs);
			}
			cl = cl.getParent();
		}

		rootURLs
			.flatMap[
				val file = new File(it.path);
				if(file.isDirectory) {
					file.listChildren
				} else {
					it.listChildren
				}
			]
			.filter[ it.endsWith(".mita") || it.endsWith(".platform") ]
			.map[ it.replace('classpath://', 'classpath:/') ]
	}
	
	protected static def Iterable<String> listChildren(File f) {
		return if(f.directory) {
			f.listFiles.flatMap[ it.listChildren ]
		} else {
			#["file://" + f.absolutePath]
		}
	}
	
	protected static def Iterable<String> listChildren(URL url) {
		val result = new LinkedList<String>();
		try {
			val urlIn = url.openStream();
       		val jarIn = new JarInputStream (urlIn);
       		for(var entry = jarIn.getNextJarEntry(); entry !== null; entry = jarIn.getNextJarEntry()) {
       			result.add("classpath://" + entry.name);
       		}
   		} finally {
   		}
   		return result;   			
	}

	protected def getProjectResources() {
		return resourceSet.resources.filter[ it.eAdapters.exists[ it instanceof CompileToCAdapter ] ]
	}

	override run() {
		loadResourceSet();
		if (resourceSet.resources.empty) {
			System.err.println("Project " + projectPath + " is empty. Aborting");
			return;
		}

		val fileSystemAccess = fileSystemAccessProvider.get();
		fileSystemAccess.outputPath = commandLine.getOptionValue('o') ?: projectPath + '/src-gen/';

		if (generator instanceof IGeneratorOnResourceSet) {
			generator.doGenerate(resourceSet, fileSystemAccess, [ it.eAdapters.exists[ it instanceof CompileToCAdapter ] ]);
		} else {
			val generatorContext = new GeneratorContext => [cancelIndicator = CancelIndicator.NullImpl];
			projectResources.forEach[generator.doGenerate(it, fileSystemAccess, generatorContext)]
		}
	}

}

class CompileToCAdapter extends AdapterImpl {
	
	
}
