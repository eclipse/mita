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

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.List
import java.util.Map
import org.eclipse.core.internal.resources.ResourceException
import org.eclipse.core.resources.IContainer
import org.eclipse.core.resources.IFile
import org.eclipse.core.resources.IMarker
import org.eclipse.core.resources.IProject
import org.eclipse.core.resources.IResource
import org.eclipse.core.runtime.CoreException
import org.eclipse.core.runtime.IProgressMonitor
import org.eclipse.core.runtime.OperationCanceledException
import org.eclipse.emf.common.util.URI
import org.eclipse.mita.program.generator.internal.IGeneratorOnResourceSet
import org.eclipse.mita.base.typesystem.infra.MitaResourceSet
import org.eclipse.mita.program.generator.internal.IGeneratorOnResourceSet
import org.eclipse.xtext.builder.BuilderParticipant
import org.eclipse.xtext.builder.EclipseResourceFileSystemAccess2
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.OutputConfiguration
import org.eclipse.xtext.resource.IResourceDescription
import org.eclipse.xtext.resource.IResourceDescription.Delta
import org.eclipse.xtext.resource.impl.ResourceDescriptionsProvider
import org.eclipse.xtext.resource.IContainer.Manager
import org.apache.log4j.Logger

class ProgramDslBuilderParticipant extends BuilderParticipant {

	private static class NoRebuildBuildContextDecorator implements IBuildContext {

		final IBuildContext delegate

		MitaResourceSet resourceSet;

		new(MitaResourceSet resourceSet, IBuildContext delegate) {
			this.resourceSet = resourceSet;
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
			return resourceSet;
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
	
	protected final static Logger logger = Logger.getLogger(BuilderParticipant);

	protected ThreadLocal<Boolean> buildSemaphore = new ThreadLocal<Boolean>();

	@Inject(optional=true)
	IGeneratorOnResourceSet generator;

	@Inject
	ResourceDescriptionsProvider resourceDescriptionsProvider;

	@Inject
	Manager containerManager;
	
	@Inject
	Provider<MitaResourceSet> resourceSetProvider;

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
			for (org.eclipse.xtext.resource.IContainer c : visibleContainers) {
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

		super.doBuild(deltas, outputConfigurations, generatorMarkers, new NoRebuildBuildContextDecorator(resourceSetProvider.get(), context),
			access, progressMonitor)
	}

	def protected void delete(IResource resource, OutputConfiguration config, EclipseResourceFileSystemAccess2 access, IProgressMonitor monitor) {
		if (monitor.isCanceled()) {
			throw new OperationCanceledException()
		}
		if (resource instanceof IContainer) {
			var IContainer container = (resource as IContainer)
			for (IResource child : container.members()) {
				delete(child, config, access, monitor)
			}
			container.delete(IResource.FORCE.bitwiseOr(IResource.KEEP_HISTORY), monitor)
		} else if (resource instanceof IFile) {
			var IFile file = (resource as IFile)
			access.deleteFile(file, config.getName(), monitor)
		} else {
			resource.delete(IResource.FORCE.bitwiseOr(IResource.KEEP_HISTORY), monitor)
		}

	}

	// need to clone the entire method since filtering resources is impossible otherwise unless we want to make 
	override protected void cleanOutput(IBuildContext ctx, OutputConfiguration config, EclipseResourceFileSystemAccess2 access, IProgressMonitor monitor) throws CoreException {
		val IProject project = ctx.getBuiltProject()
		for (IContainer container : getOutputs(project, config)) {
			if (!container.exists()) {
				return;
			}
			if (canClean(container, config)) {
				for (IResource resource : container.members().filter [
					val path = it.projectRelativePath;
					return path.toString != "src-gen/Makefile"
				]) {
					try {
						if (!config.isKeepLocalHistory()) {
							resource.delete(IResource.FORCE, monitor)
						} else if (access === null) {
							resource.delete(IResource.FORCE.bitwiseOr(IResource.KEEP_HISTORY), monitor)
						} else {
							delete(resource, config, access, monitor)
						}
					} catch (ResourceException e) {
						logger.warn('''Couldn't delete «resource.getLocation()». «e.getMessage()»''')
					}

				}
			} else if (config.isCleanUpDerivedResources()) {
				var resources = derivedResourceMarkers.findDerivedResources(container, null).filter [
					val path = it.projectRelativePath;
					return path.toString != "src-gen/Makefile"
				]
				for (IFile iFile : resources) {
					if (monitor.isCanceled()) {
						throw new OperationCanceledException()
					}
					try {
						if (access !== null) {
							access.deleteFile(iFile, config.getName(), monitor)
						} else {
							iFile.delete(true, config.isKeepLocalHistory(), monitor)
						}
					} catch (ResourceException e) {
						logger.warn('''Couldn't delete «iFile.getLocation()». «e.getMessage()»''')
					}

				}
			}
		}
	}

}
