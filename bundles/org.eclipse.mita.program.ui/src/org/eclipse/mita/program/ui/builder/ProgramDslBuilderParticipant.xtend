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

package org.eclipse.mita.program.ui.builder

import org.eclipse.mita.program.generator.internal.IGeneratorOnResourceSet
import com.google.inject.Inject
import java.util.List
import java.util.Map
import org.eclipse.core.resources.IMarker
import org.eclipse.core.runtime.CoreException
import org.eclipse.core.runtime.IProgressMonitor
import org.eclipse.emf.common.util.URI
import org.eclipse.xtext.builder.BuilderParticipant
import org.eclipse.xtext.builder.EclipseResourceFileSystemAccess2
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.OutputConfiguration
import org.eclipse.xtext.resource.IContainer
import org.eclipse.xtext.resource.IResourceDescription
import org.eclipse.xtext.resource.IResourceDescription.Delta
import org.eclipse.xtext.resource.impl.ResourceDescriptionsProvider

class ProgramDslBuilderParticipant extends BuilderParticipant {

	private static class NoRebuildBuildContextDecorator implements IBuildContext {

		private final IBuildContext delegate

		public new(IBuildContext delegate) {
			this.delegate = delegate;
		}

		override getBuildType() {
			return delegate.buildType;
		}

		override getBuiltProject() {
			return delegate.builtProject;
		}

		override getDeltas() {
			return delegate.deltas;
		}

		override getResourceSet() {
			return delegate.resourceSet;
		}

		override isSourceLevelURI(URI uri) {
			return delegate.isSourceLevelURI(uri);
		}

		override needRebuild() {
			/* We do not want to allow a rebuild to prevent Xtext from triggering a full rebuild
			 * in conjunction with the CDT builder. Thus we do nothing here. 
			 */
		}

	}

	protected ThreadLocal<Boolean> buildSemaphore = new ThreadLocal<Boolean>();

	@Inject(optional=true)
	private IGeneratorOnResourceSet generator;

	@Inject
	private ResourceDescriptionsProvider resourceDescriptionsProvider;

	@Inject
	private IContainer.Manager containerManager;

	override build(IBuildContext context, IProgressMonitor monitor) throws CoreException {
		buildSemaphore.set(false);
		super.build(context, monitor)
	}

	override protected handleChangedContents(Delta delta, IBuildContext context, EclipseResourceFileSystemAccess2 fileSystemAccess) throws CoreException {
		super.handleChangedContents(delta, context, fileSystemAccess)
		if (!buildSemaphore.get() && generator !== null) {
			invokeGenerator(delta, context, fileSystemAccess);
		}
	}

	protected def void invokeGenerator(Delta delta, IBuildContext context, IFileSystemAccess2 fileSystemAccess) {
		buildSemaphore.set(true);
		val resource = context.getResourceSet().getResource(delta.getUri(), true);
		if (shouldGenerate(resource, context)) {
			val index = resourceDescriptionsProvider.createResourceDescriptions();
			val resDesc = index.getResourceDescription(resource.getURI());
			val visibleContainers = containerManager.getVisibleContainers(resDesc, index);
			for (IContainer c : visibleContainers) {
				for (IResourceDescription rd : c.getResourceDescriptions()) {
					context.getResourceSet().getResource(rd.getURI(), true);
				}
			}

			generator.doGenerate(context.getResourceSet(), fileSystemAccess);
		}
	}

	override protected doBuild(List<Delta> deltas, Map<String, OutputConfiguration> outputConfigurations,
		Map<OutputConfiguration, Iterable<IMarker>> generatorMarkers, IBuildContext context,
		EclipseResourceFileSystemAccess2 access, IProgressMonitor progressMonitor) throws CoreException {

		super.doBuild(deltas, outputConfigurations, generatorMarkers, new NoRebuildBuildContextDecorator(context),
			access, progressMonitor)
	}

}
