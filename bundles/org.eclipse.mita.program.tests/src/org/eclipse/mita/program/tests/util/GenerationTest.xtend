/** 
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 * Contributors:
 * Bosch Connected Devices and Solutions GmbH - initial contribution
 * SPDX-License-Identifier: EPL-2.0
 */
package org.eclipse.mita.program.tests.util

import com.google.inject.Inject
import com.google.inject.Provider
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.lang.annotation.Retention
import java.lang.annotation.RetentionPolicy
import java.util.ArrayList
import java.util.Collection
import java.util.Collections
import java.util.List
import java.util.Scanner
import org.eclipse.core.resources.IFile
import org.eclipse.core.resources.IMarker
import org.eclipse.core.resources.IProject
import org.eclipse.core.resources.IResource
import org.eclipse.core.resources.IResourceVisitor
import org.eclipse.core.resources.IncrementalProjectBuilder
import org.eclipse.core.runtime.CoreException
import org.eclipse.core.runtime.NullProgressMonitor
import org.eclipse.emf.common.util.TreeIterator
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.emf.ecore.util.EcoreUtil.Copier
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.scoping.ILibraryProvider
import org.eclipse.mita.base.types.ImportStatement
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.Type
import org.eclipse.mita.base.types.TypeKind
import org.eclipse.mita.base.typesystem.infra.MitaBaseResource
import org.eclipse.mita.base.util.CopySourceAdapter
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramFactory
import org.eclipse.mita.program.ThrowExceptionStatement
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.xtext.linking.lazy.LazyLinkingResource
import org.eclipse.xtext.nodemodel.ICompositeNode
import org.eclipse.xtext.nodemodel.ILeafNode
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.util.CancelIndicator
import org.junit.Assert
import org.junit.runner.RunWith
import org.xpect.XpectImport
import org.xpect.XpectInvocation
import org.xpect.parameter.IStatementRelatedRegion
import org.xpect.runner.LiveExecutionType
import org.xpect.runner.Xpect
import org.xpect.runner.XpectRunner
import org.xpect.setup.XpectSetupFactory
import org.xpect.state.Creates
import org.xpect.state.XpectStateAnnotation
import org.xpect.xtext.lib.setup.ThisResource
import org.xpect.xtext.lib.setup.XtextStandaloneSetup
import org.xpect.xtext.lib.setup.XtextWorkspaceSetup

import static org.eclipse.emf.ecore.util.EcoreUtil.getRootContainer

import static extension org.eclipse.mita.base.util.BaseUtils.force

@RunWith(XpectRunner)
@XpectImport(#[XtextStandaloneSetup, XtextWorkspaceSetup])
class GenerationTest {
	@Inject Provider<XtextResourceSet> resourceSetProvider
	@Inject package TestProjectHelper helper
	@Inject package ExternalCommandExecutor exec
	@Inject package GeneratorUtils genUtils
	@Inject ILibraryProvider libraryProvider

	@Xpect(liveExecution=LiveExecutionType.FAST)
	def void noCompileErrors(@ContextObject EObject contextObject) {
		if ("true".equals(System.getenv("DISABLE_NO_COMPILE_ERRORS"))) {
			return;
		}
		[|
			try {
				val IProject project = helper.createEmptyTestProject()
				val Resource resource = createProgram(contextObject)
				
				project.refreshLocal(IResource.DEPTH_INFINITE, new NullProgressMonitor())
				if (resource instanceof MitaBaseResource) {
					if(resource.latestSolution === null) {
						resource.collectAndSolveTypes(resource.contents.head);
					}
				}
				resource.save(Collections.emptyMap())
				project.build(IncrementalProjectBuilder.FULL_BUILD, new NullProgressMonitor())
				assertGeneratedCodeExists(project, resource)
				compile(project)
			} catch (CoreException | IOException e) {
				e.printStackTrace()
				Assert.fail('''Error in test setup: «e.getMessage()»''')
			}
		].apply()
	}

	def private void assertGeneratedCodeExists(IProject project, Resource resource) {
		val Program program = (resource.getContents().get(0) as Program)
		if (genUtils.containsCodeRelevantContent(program)) {
			assertFileExists(project, "src-gen/application.c")
		}
	}

	def private void compile(IProject project) throws CoreException {
		try {
			exec.execute(Collections.singletonList("make"), new File(project.getFolder("src-gen").getLocationURI()))
		} catch (Exception e) {
			var String code = getGeneratedSource(project)
			Assert.fail('''
				«e.getMessage()»
				
				 Generated Code:
				«code»
			''')
		}

	}

	def private void assertFileExists(IProject project, String filePath) {
		var IFile file = project.getFile(filePath)
		Assert.assertTrue('''File does not exists: «filePath»''', file.exists())
	}

	def private String getGeneratedSource(IProject project) throws CoreException {
		var IFile applicationCFile = project.getFile("src-gen/application.c")
		if (applicationCFile.exists()) {
			var InputStream stream = applicationCFile.getContents()
			var Scanner scanner = new Scanner(stream, "UTF-8")
			try {
				return scanner.useDelimiter("\\A").next()
			} finally {
				scanner.close;
			}

		} else {
			return "Application.c file does not exist"
		}
	}

	def private void linkOrigin(EObject copy, EObject origin) {
		copy.eAdapters().add(new CopySourceAdapter(origin))
	}

	def private Resource createProgram(EObject contextObject) {
		val ResourceSet set = resourceSetProvider.get()
		val Resource resource = set.createResource(URI.createPlatformResourceURI("unittestprj/application.mita", true))
		val libs = libraryProvider.standardLibraries;
		val stdlibUri = libs.filter[it.toString.endsWith(MitaBaseResource.PROGRAM_EXT)]
		val stdlib = stdlibUri.map[set.getResource(it, true)].filterNull.map[it.contents.filter(Program).head].force;
		
		var Copier copier = new Copier()
		var Program originalProgram = (getRootContainer(contextObject) as Program)
		copier.copy(originalProgram)
		copier.copyReferences()
		copier.forEach([ o, c |
			{
				linkOrigin(c, o)
			}
		])
		var Program program = ProgramFactory.eINSTANCE.createProgram()
		program.setName("unittest")
		for (ImportStatement i : originalProgram.getImports()) {
			addToContainingFeature(program, i, copier.get(i))
		}
		copyReferences(contextObject, copier, program)
		
		resource.getContents().add(program)
	
		((resource as LazyLinkingResource)).resolveLazyCrossReferences(CancelIndicator.NullImpl)
		return resource
	}

	def private boolean copyObject(EObject t) {
		return !(t instanceof SumAlternative || t instanceof TypeKind)
	}

	def private void copyReferences(EObject contextObject, Copier copier, Program program) {
		// Add all references from the snippet under test
		var TreeIterator<EObject> eAllContents = contextObject.eAllContents()
		while (eAllContents.hasNext()) {
			var EObject next = eAllContents.next()
			if (next instanceof ElementReferenceExpression) {
				var ElementReferenceExpression ref = (next as ElementReferenceExpression)
				var EObject referencedObject = ref.getReference()
				if (EcoreUtil.equals(getRootContainer(contextObject), getRootContainer(referencedObject)) &&
					!EcoreUtil.isAncestor(contextObject, referencedObject)) {
					copyReferences(referencedObject, copier, program)
				}
			}
			if (next instanceof PresentTypeSpecifier) {
				var Type type = ((next as PresentTypeSpecifier)).getType()
				if (copyObject(type) && EcoreUtil.equals(getRootContainer(contextObject), getRootContainer(type))) {
					program.getTypes().add((copier.get(type) as Type))
				}
			}
			if (next instanceof ThrowExceptionStatement) {
				var Type type = ((next as ThrowExceptionStatement)).getExceptionType()
				if (EcoreUtil.equals(getRootContainer(contextObject), getRootContainer(type))) {
					program.getTypes().add((copier.get(type) as Type))
				}
			}
		}
		// SumAlternatives are added by their parent
		if (copyObject(contextObject)) {
			// Add snippet under test
			addToContainingFeature(program, contextObject, copier.get(contextObject))
		}
	}

	def private void addToContainingFeature(Program program, EObject original, EObject copy) {
		var EStructuralFeature containingFeature = original.eContainingFeature()
		if (containingFeature.isMany()) {
			var Collection<EObject> collection = (program.eGet(containingFeature) as Collection<EObject>)
			collection.add(copy)
		}
	}

	static class ErrorMarkerCollector implements IResourceVisitor {
		List<String> errors = new ArrayList()

		override boolean visit(IResource resource) throws CoreException {
			val IMarker[] markers = resource.findMarkers(IMarker.PROBLEM, true, 1)
			for (IMarker marker : markers) {
				if (marker.exists() &&
					marker.getAttribute(IMarker.SEVERITY, IMarker.SEVERITY_INFO) === IMarker.SEVERITY_ERROR) {
					errors.add(formatMessage(resource, marker))
				}
			}
			return true
		}

		def protected String formatMessage(IResource resource, IMarker marker) throws CoreException {
			val StringBuilder builder = new StringBuilder()
			builder.append("ERROR")
			builder.append(" in ")
			builder.append(resource.getProjectRelativePath().toString())
			builder.append(" at ")
			builder.append(marker.getAttribute(IMarker.LINE_NUMBER))
			builder.append(Character.valueOf(':').charValue)
			builder.append(marker.getAttribute(IMarker.MESSAGE))
			return builder.toString()
		}

		def List<String> getErrors() {
			return errors
		}
	}

	@Retention(RetentionPolicy.RUNTIME)
	@XpectStateAnnotation
	@XpectImport(ContextObjectProvider)
	public static annotation ContextObject {
		@XpectSetupFactory static class ContextObjectProvider {
			final EObject contextObject

			new(@ThisResource XtextResource resource, XpectInvocation statement) {
				var ICompositeNode rootNode = resource.getParseResult().getRootNode()
				var IStatementRelatedRegion statementRegion = statement.getExtendedRegion()
				var ILeafNode leaf = NodeModelUtils.findLeafNodeAtOffset(rootNode,
					statementRegion.getOffset() + statementRegion.getLength())
				contextObject = NodeModelUtils.findActualSemanticObjectFor(leaf)
			}

			@Creates(ContextObject) def EObject getCodeFragment() {
				return contextObject
			}
		}
	}
}
