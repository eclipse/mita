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

package org.eclipse.mita.platform

import com.google.inject.Binder
import com.google.inject.name.Names
import org.eclipse.mita.base.scoping.BaseQualifiedNameProvider
import org.eclipse.mita.base.scoping.ILibraryProvider
import org.eclipse.mita.base.scoping.LibraryProviderImpl
import org.eclipse.mita.base.scoping.MitaContainerManager
import org.eclipse.mita.base.scoping.MitaResourceSetBasedAllContainersState
import org.eclipse.mita.base.scoping.MitaTypeSystem
import org.eclipse.mita.base.scoping.TypesGlobalScopeProvider
import org.eclipse.mita.base.types.typesystem.ITypeSystem
import org.eclipse.mita.base.typesystem.IConstraintFactory
import org.eclipse.mita.base.typesystem.infra.MitaBaseResource
import org.eclipse.mita.base.typesystem.infra.MitaLinker
import org.eclipse.mita.base.typesystem.infra.MitaTypeLinker
import org.eclipse.mita.base.typesystem.solver.CoerciveSubtypeSolver
import org.eclipse.mita.base.typesystem.solver.IConstraintSolver
import org.eclipse.mita.base.validation.BaseResourceValidator
import org.eclipse.mita.platform.infra.PlatformLinker
import org.eclipse.mita.platform.scoping.PlatformDslImportScopeProvider
import org.eclipse.mita.platform.scoping.PlatformDslResourceDescriptionStrategy
import org.eclipse.mita.platform.typesystem.PlatformConstraintFactory
import org.eclipse.xtext.linking.lazy.LazyURIEncoder
import org.eclipse.xtext.resource.IDefaultResourceDescriptionStrategy
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.xtext.scoping.impl.AbstractDeclarativeScopeProvider
import org.eclipse.xtext.service.DefaultRuntimeModule
import org.eclipse.xtext.validation.IResourceValidator
import org.eclipse.mita.base.typesystem.infra.AbstractSizeInferrer
import org.eclipse.mita.base.typesystem.infra.NullSizeInferrer
import org.eclipse.mita.base.typesystem.solver.NullSolver

class PlatformDSLRuntimeModule extends AbstractPlatformDSLRuntimeModule {

	override configure(Binder binder) {
		super.configure(binder)
		binder.bind(ITypeSystem).toInstance(MitaTypeSystem.getInstance())
		binder.bind(IDefaultResourceDescriptionStrategy).to(PlatformDslResourceDescriptionStrategy)
		binder.bind(DefaultRuntimeModule).annotatedWith(Names.named("injectingModule")).toInstance(this)
		binder.bind(ILibraryProvider).to(LibraryProviderImpl);
		binder.bind(IResourceValidator).to(BaseResourceValidator);
	
		binder.bind(IConstraintFactory).to(PlatformConstraintFactory);
		binder.bind(IConstraintSolver).annotatedWith(Names.named("mainSolver")).to(CoerciveSubtypeSolver);
		binder.bind(IConstraintSolver).annotatedWith(Names.named("sizeSolver")).to(NullSolver);
		binder.bind(MitaTypeLinker).annotatedWith(Names.named("typeLinker")).to(MitaTypeLinker);
		binder.bind(MitaTypeLinker).annotatedWith(Names.named("typeDependentLinker")).to(PlatformLinker);
		binder.bind(AbstractSizeInferrer).to(NullSizeInferrer);
	}

	override bindIGlobalScopeProvider() {
		TypesGlobalScopeProvider
	}
	
	override bindIQualifiedNameProvider() {
		return BaseQualifiedNameProvider
	}
		
	override configureIScopeProviderDelegate(Binder binder) {
		binder.bind(IScopeProvider)
                .annotatedWith(Names
                        .named(AbstractDeclarativeScopeProvider.NAMED_DELEGATE))
                .to(PlatformDslImportScopeProvider);
	}

	override bindXtextResource() {
		return MitaBaseResource
	}
	
	override bindILinker() {
		return MitaLinker
	}
//	override bindXtextResourceSet() {
//		return MitaResourceSet
//	}
	override bindIContainer$Manager() {
		return MitaContainerManager;
	}

	override bindIAllContainersState$Provider() {
		return MitaResourceSetBasedAllContainersState.Provider;
	}
	
	override configureUseIndexFragmentsForLazyLinking(Binder binder) {
		binder.bind(boolean).annotatedWith(Names.named(LazyURIEncoder.USE_INDEXED_FRAGMENTS_BINDING)).toInstance(false);
	}
	
}
