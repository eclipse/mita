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

package org.eclipse.mita.program.tests.util;

import static org.eclipse.emf.ecore.util.EcoreUtil.getRootContainer;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.List;
import java.util.Scanner;

import org.eclipse.core.resources.IFile;
import org.eclipse.core.resources.IMarker;
import org.eclipse.core.resources.IProject;
import org.eclipse.core.resources.IResource;
import org.eclipse.core.resources.IResourceVisitor;
import org.eclipse.core.resources.IncrementalProjectBuilder;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.NullProgressMonitor;
import org.eclipse.emf.common.util.TreeIterator;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EStructuralFeature;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.ResourceSet;
import org.eclipse.emf.ecore.util.EcoreUtil;
import org.eclipse.emf.ecore.util.EcoreUtil.Copier;
import org.eclipse.mita.base.expressions.ElementReferenceExpression;
import org.eclipse.mita.base.expressions.FeatureCall;
import org.eclipse.mita.base.types.ImportStatement;
import org.eclipse.mita.base.types.Type;
import org.eclipse.mita.base.types.TypeSpecifier;
import org.eclipse.mita.program.Program;
import org.eclipse.mita.program.ProgramFactory;
import org.eclipse.mita.program.ThrowExceptionStatement;
import org.eclipse.mita.program.generator.GeneratorUtils;
import org.eclipse.mita.program.tests.util.GenerationTest.ContextObject.ContextObjectProvider;
import org.eclipse.xtext.linking.lazy.LazyLinkingResource;
import org.eclipse.xtext.nodemodel.ICompositeNode;
import org.eclipse.xtext.nodemodel.ILeafNode;
import org.eclipse.xtext.nodemodel.util.NodeModelUtils;
import org.eclipse.xtext.resource.XtextResource;
import org.eclipse.xtext.resource.XtextResourceSet;
import org.eclipse.xtext.util.CancelIndicator;
import org.junit.Assert;
import org.junit.runner.RunWith;
import org.xpect.XpectImport;
import org.xpect.XpectInvocation;
import org.xpect.parameter.IStatementRelatedRegion;
import org.xpect.runner.LiveExecutionType;
import org.xpect.runner.Xpect;
import org.xpect.runner.XpectRunner;
import org.xpect.setup.XpectSetupFactory;
import org.xpect.state.Creates;
import org.xpect.state.XpectStateAnnotation;
import org.xpect.xtext.lib.setup.ThisResource;
import org.xpect.xtext.lib.setup.XtextStandaloneSetup;
import org.xpect.xtext.lib.setup.XtextWorkspaceSetup;

import com.google.inject.Inject;
import com.google.inject.Provider;

@RunWith(XpectRunner.class)
@XpectImport({ XtextStandaloneSetup.class, XtextWorkspaceSetup.class })
public class GenerationTest {

	@Inject
	private Provider<XtextResourceSet> resourceSetProvider;

	@Inject
	TestProjectHelper helper;

	@Inject
	ExternalCommandExecutor exec;
	
	@Inject
	GeneratorUtils genUtils;

	@Xpect(liveExecution = LiveExecutionType.FAST)
	public void noCompileErrors(@ContextObject EObject contextObject) {
		if ("true".equals(System.getenv("DISABLE_NO_COMPILE_ERRORS"))) {
			return;
		}
		try {
			IProject project = helper.createEmptyTestProject();
			Resource resource = createProgram(contextObject);
			project.refreshLocal(IResource.DEPTH_INFINITE, new NullProgressMonitor());

			resource.save(Collections.emptyMap());

			project.build(IncrementalProjectBuilder.FULL_BUILD, new NullProgressMonitor());

			assertGeneratedCodeExists(project, resource);

			compile(project);
		} catch (CoreException | IOException e) {
			e.printStackTrace();
			Assert.fail("Error in test setup: " + e.getMessage());
		}
	}

	private void assertGeneratedCodeExists(IProject project, Resource resource) {
		final Program program = (Program) resource.getContents().get(0);
		if (genUtils.containsCodeRelevantContent(program)) {
			assertFileExists(project, "src-gen/application.c");
		}
	}

	private void compile(IProject project) throws CoreException {
		try {
			exec.execute(Collections.singletonList("make"),
					new File(project.getFolder("src-gen").getLocationURI()));
		} catch (Exception e) {
			String code = getGeneratedSource(project);
			Assert.fail(e.getMessage() + "\n\n Generated Code:\n" + code);
		}
	}

	private void assertFileExists(IProject project, String filePath) {
		IFile file = project.getFile(filePath);
		Assert.assertTrue("File does not exists: " + filePath, file.exists());
	}

	private String getGeneratedSource(IProject project) throws CoreException {
		IFile applicationCFile = project.getFile("src-gen/application.c");
		if (applicationCFile.exists()) {
			InputStream stream = applicationCFile.getContents();
			try (Scanner scanner = new Scanner(stream, "UTF-8")) {
				return scanner.useDelimiter("\\A").next();
			}
		} else {
			return "Application.c file does not exist";
		}
	}

	private Resource createProgram(EObject contextObject) {
		Copier c = new Copier();
		Program originalProgram = (Program) getRootContainer(contextObject);
		c.copy(originalProgram);
		c.copyReferences();

		Program program = ProgramFactory.eINSTANCE.createProgram();
		program.setName("unittest");

		for (ImportStatement i : originalProgram.getImports()) {
			addToContainingFeature(program, i, c.get(i));
		}

		// Add all references from the snippet under test
		TreeIterator<EObject> eAllContents = contextObject.eAllContents();
		while (eAllContents.hasNext()) {
			EObject next = eAllContents.next();
			if (next instanceof ElementReferenceExpression) {
				ElementReferenceExpression ref = (ElementReferenceExpression) next;
				EObject referencedObject = ref.getReference();
				if (EcoreUtil.equals(getRootContainer(contextObject), getRootContainer(referencedObject))
						&& !EcoreUtil.isAncestor(contextObject, referencedObject)) {
					addToContainingFeature(program, referencedObject, c.get(referencedObject));
				}
			}
			if (next instanceof FeatureCall) {
				FeatureCall feature = (FeatureCall) next;
				if (feature.isOperationCall()) {
					EObject featureObject = feature.getFeature();
					if (EcoreUtil.equals(getRootContainer(contextObject), getRootContainer(featureObject))
							&& !EcoreUtil.isAncestor(contextObject, featureObject)) {
						addToContainingFeature(program, featureObject, c.get(featureObject));
					}
				}
			}
			if (next instanceof TypeSpecifier) {
				Type type = ((TypeSpecifier) next).getType();
				if (EcoreUtil.equals(getRootContainer(contextObject), getRootContainer(type))) {
					program.getTypes().add((Type) c.get(type));
				}
			}

			if (next instanceof ThrowExceptionStatement) {
				Type type = ((ThrowExceptionStatement) next).getExceptionType();
				if (EcoreUtil.equals(getRootContainer(contextObject), getRootContainer(type))) {
					program.getTypes().add((Type) c.get(type));
				}
			}
		}
		// Add snippet under test
		addToContainingFeature(program, contextObject, c.get(contextObject));

		ResourceSet set = resourceSetProvider.get();
		Resource resource = set.createResource(URI.createPlatformResourceURI("unittestprj/application.mita", true));
		resource.getContents().add(program);
		((LazyLinkingResource) resource).resolveLazyCrossReferences(CancelIndicator.NullImpl);

		return resource;
	}

	private void addToContainingFeature(Program program, EObject original, EObject copy) {
		EStructuralFeature containingFeature = original.eContainingFeature();
		if (containingFeature.isMany()) {
			@SuppressWarnings({ "rawtypes", "unchecked" })
			Collection<EObject> collection = (Collection) program.eGet(containingFeature);
			collection.add(copy);
		}
	}

	public static class ErrorMarkerCollector implements IResourceVisitor {

		private List<String> errors = new ArrayList<>();;

		@Override
		public boolean visit(IResource resource) throws CoreException {
			final IMarker[] markers = resource.findMarkers(IMarker.PROBLEM, true, 1);
			for (IMarker marker : markers) {
				if (!marker.exists()
						|| marker.getAttribute(IMarker.SEVERITY, IMarker.SEVERITY_INFO) != IMarker.SEVERITY_ERROR) {
					continue;
				}
				errors.add(formatMessage(resource, marker));
			}
			return true;
		}

		protected String formatMessage(IResource resource, IMarker marker) throws CoreException {
			final StringBuilder builder = new StringBuilder();

			builder.append("ERROR");
			builder.append(" in ");
			builder.append(resource.getProjectRelativePath().toString());
			builder.append(" at ");
			builder.append(marker.getAttribute(IMarker.LINE_NUMBER));
			builder.append(':');
			builder.append(marker.getAttribute(IMarker.MESSAGE));

			return builder.toString();
		}

		public List<String> getErrors() {
			return errors;
		}
	};

	@Retention(RetentionPolicy.RUNTIME)
	@XpectStateAnnotation
	@XpectImport(ContextObjectProvider.class)
	public static @interface ContextObject {

		@XpectSetupFactory
		public static class ContextObjectProvider {

			private final EObject contextObject;

			public ContextObjectProvider(@ThisResource XtextResource resource, XpectInvocation statement) {
				ICompositeNode rootNode = resource.getParseResult().getRootNode();
				IStatementRelatedRegion statementRegion = statement.getExtendedRegion();
				ILeafNode leaf = NodeModelUtils.findLeafNodeAtOffset(rootNode,
						statementRegion.getOffset() + statementRegion.getLength());
				contextObject = NodeModelUtils.findActualSemanticObjectFor(leaf);
			}

			@Creates(ContextObject.class)
			public EObject getCodeFragment() {
				return contextObject;
			}
		}
	}

}
