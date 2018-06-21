/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
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

package org.eclipse.mita.program.generator.tests;

import org.eclipse.mita.program.Program
import org.eclipse.mita.program.tests.util.CProjectHelper
import org.eclipse.mita.program.tests.util.ProgramDslInjectorProvider
import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.cdt.core.dom.ast.IASTFunctionDefinition
import org.eclipse.cdt.core.dom.ast.IASTNode
import org.eclipse.cdt.core.dom.ast.IASTProblemStatement
import org.eclipse.cdt.core.dom.ast.IASTTranslationUnit
import org.eclipse.cdt.core.dom.ast.gnu.c.GCCLanguage
import org.eclipse.cdt.core.model.ILanguage
import org.eclipse.cdt.core.parser.DefaultLogService
import org.eclipse.cdt.core.parser.FileContent
import org.eclipse.cdt.core.parser.IncludeFileContentProvider
import org.eclipse.cdt.core.parser.ScannerInfo
import org.eclipse.core.runtime.CoreException
import org.eclipse.emf.common.util.URI
import org.eclipse.xtext.generator.IGenerator2
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.eclipse.xtext.util.StringInputStream
import org.junit.Before
import org.junit.runner.RunWith

import static org.junit.Assert.*
import org.eclipse.core.runtime.Assert

@RunWith(XtextRunner)
@InjectWith(ProgramDslInjectorProvider)
public class AbstractGeneratorTest {

	@Inject
	protected ParseHelper<Program> parseHelper;

	@Inject
	protected IGenerator2 generator;

	@Inject
	private Provider<XtextResourceSet> resourceSetProvider;

	@Inject extension CProjectHelper

	@Before
	def void setup() {
		createEmptyGenerationProject();
	}

	/**
	 * Parses Mita code and generates the C code in memory.
	 * 
	 * @param Mita_code the code to parse and generate C code from
	 * @return the in-memory filesystem containing the code
	 * @throws Exception if something goes wrong (very helpful, isn't it?)
	 */
	protected def InMemoryFileSystemAccess generateFrom(CharSequence Mita_code) throws Exception {
		val project = generationProject;
		Assert.isTrue(project.accessible)
		val appfile = project.getFile("application.mita")
		if (!appfile.exists) {
			appfile.create(new StringInputStream(Mita_code.toString), true, null)
		} else
			appfile.setContents(new StringInputStream(Mita_code.toString), true, false, null)

		val resourceSet = resourceSetProvider.get();
		val resource = resourceSet.getResource(URI.createPlatformResourceURI(appfile.fullPath.toString, true), true)
		val program = resource.contents.filter(Program).head
		val fsa = new InMemoryFileSystemAccess()
		generator.doGenerate(program.eResource(), fsa, null)
		return fsa
	}

	/**
	 * Parses generated C code using the CDT
	 * 
	 * @param fsa the filesystem to read the code from
	 * @param filename the name of the file to read
	 * @return the AST for the C file
	 */
	protected def Pair<String, IASTTranslationUnit> parseCFile(InMemoryFileSystemAccess fsa,
		String filename) throws CoreException {
		val rawFileContent = fsa.readTextFile(filename).toString();
		val fileContent = FileContent.create(filename, rawFileContent.toCharArray());
		val scanInfo = new ScannerInfo();
		val fileCreator = IncludeFileContentProvider.getEmptyFilesProvider();
		val unit = GCCLanguage.getDefault().getASTTranslationUnit(fileContent, scanInfo, fileCreator, null,
			ILanguage.OPTION_IS_SOURCE_UNIT, new DefaultLogService());

		return rawFileContent -> unit;
	}

	/**
	 * Parses Mita code, generates C code from it and parses the generated C code.
	 * 
	 * @param application code the application to generate C code from
	 * @return the generated parsed C code
	 */
	protected def generateAndParseApplication(CharSequence application) throws Exception {
		return generateAndParseApplication(application, "application.c")
	}
	
	protected def generateAndParseApplication(CharSequence application, String fileName) throws Exception {
		val fsa = generateFrom(application);
		return parseCFile(fsa, fileName);
	}

	protected def findFunction(IASTTranslationUnit unit, String name) {
		return unit.declarations.filter(IASTFunctionDefinition).findFirst[x|x.declarator.name.toString == name]
	}

	protected def assertNoCompileErrors(Pair<String, IASTTranslationUnit> codeAndUnit) {
		val problems = codeAndUnit.value.descendants.filter(IASTProblemStatement);
		if (!problems.isNullOrEmpty) {
			val errorMsg = problems.map[problem.messageWithLocation].join("\n")
			fail("Generated C code has compilation errors: \n" + errorMsg + "\nSee code below.\n" + codeAndUnit.key);
		}
	}

	protected def Iterable<IASTNode> getDescendants(IASTNode node) {
		return node.children.map[x|#[x] + x.descendants].flatten
	}

}
