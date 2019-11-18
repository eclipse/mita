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

/*
 * generated by Xtext 2.10.0
 */
package org.eclipse.mita.program

import com.google.inject.Binder
import com.google.inject.name.Names
import org.eclipse.mita.base.expressions.terminals.ExpressionsValueConverterService
import org.eclipse.mita.base.scoping.BaseQualifiedNameProvider
import org.eclipse.mita.base.scoping.ILibraryProvider
import org.eclipse.mita.base.scoping.LibraryProviderImpl
import org.eclipse.mita.base.scoping.MitaContainerManager
import org.eclipse.mita.base.scoping.MitaResourceSetBasedAllContainersState
import org.eclipse.mita.base.scoping.MitaTypeSystem
import org.eclipse.mita.base.scoping.TypesGlobalScopeProvider
import org.eclipse.mita.base.types.typesystem.ITypeSystem
import org.eclipse.mita.base.typesystem.IConstraintFactory
import org.eclipse.mita.base.typesystem.infra.AbstractSizeInferrer
import org.eclipse.mita.base.typesystem.infra.MitaBaseResource
import org.eclipse.mita.base.typesystem.infra.MitaLinker
import org.eclipse.mita.base.typesystem.infra.MitaTypeLinker
import org.eclipse.mita.base.typesystem.solver.CoerciveSubtypeSolver
import org.eclipse.mita.base.typesystem.solver.IConstraintSolver
import org.eclipse.mita.base.validation.BaseResourceValidator
import org.eclipse.mita.program.formatting.ProgramDslFormatter
import org.eclipse.mita.program.generator.ProgramDslGenerator
import org.eclipse.mita.program.generator.internal.IGeneratorOnResourceSet
import org.eclipse.mita.program.inferrer.ProgramSizeInferrer
import org.eclipse.mita.program.inferrer.SizeConstraintSolver
import org.eclipse.mita.program.scoping.ProgramDslImportScopeProvider
import org.eclipse.mita.program.scoping.ProgramDslResourceDescriptionStrategy
import org.eclipse.mita.program.typesystem.ProgramConstraintFactory
import org.eclipse.mita.program.typesystem.ProgramLinker
import org.eclipse.xtext.conversion.IValueConverterService
import org.eclipse.xtext.formatting.IFormatter
import org.eclipse.xtext.linking.lazy.LazyURIEncoder
import org.eclipse.xtext.resource.IDefaultResourceDescriptionStrategy
import org.eclipse.xtext.scoping.IGlobalScopeProvider
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.xtext.scoping.impl.AbstractDeclarativeScopeProvider
import org.eclipse.xtext.service.DefaultRuntimeModule
import org.eclipse.xtext.ui.editor.DirtyStateManager
import org.eclipse.xtext.ui.editor.IDirtyStateManager
import org.eclipse.xtext.validation.CompositeEValidator
import org.eclipse.xtext.validation.IResourceValidator
import org.eclipse.mita.program.inferrer.SizeConstraintSolver

class ProgramDslRuntimeModule extends AbstractProgramDslRuntimeModule {

	override configure(Binder binder) {
		super.configure(binder)
		binder.bind(ITypeSystem).toInstance(MitaTypeSystem.getInstance())
		binder.bind(IDefaultResourceDescriptionStrategy).to(ProgramDslResourceDescriptionStrategy)
		binder.bind(boolean).annotatedWith(Names.named(CompositeEValidator.USE_EOBJECT_VALIDATOR)).toInstance(false)
		binder.bind(DefaultRuntimeModule).annotatedWith(Names.named("injectingModule")).toInstance(this)
		binder.bind(ILibraryProvider).to(LibraryProviderImpl);
		binder.bind(IResourceValidator).to(BaseResourceValidator);
		
		binder.bind(IConstraintFactory).to(ProgramConstraintFactory);
		binder.bind(IConstraintSolver).annotatedWith(Names.named("mainSolver")).to(CoerciveSubtypeSolver);
		binder.bind(IConstraintSolver).annotatedWith(Names.named("sizeSolver")).to(SizeConstraintSolver);
		binder.bind(MitaTypeLinker).annotatedWith(Names.named("typeLinker")).to(MitaTypeLinker);
		binder.bind(MitaTypeLinker).annotatedWith(Names.named("typeDependentLinker")).to(ProgramLinker);
		binder.bind(IDirtyStateManager).to(DirtyStateManager);
		binder.bind(AbstractSizeInferrer).to(ProgramSizeInferrer);
	}
	override configureIScopeProviderDelegate(Binder binder) {
		binder.bind(IScopeProvider).annotatedWith(Names.named(AbstractDeclarativeScopeProvider.NAMED_DELEGATE)).to(
			ProgramDslImportScopeProvider);
	}

	override bindIQualifiedNameProvider() {
		return BaseQualifiedNameProvider
	}

	override Class<? extends IGlobalScopeProvider> bindIGlobalScopeProvider() {
		return TypesGlobalScopeProvider;
	}

	override Class<? extends IFormatter> bindIFormatter() {
		return ProgramDslFormatter;
	}

	def Class<? extends IGeneratorOnResourceSet> bindIGeneratorOnResourceSet() {
		return ProgramDslGenerator;
	}
	
	override Class<? extends IValueConverterService> bindIValueConverterService() {
		return ExpressionsValueConverterService
	}
		
	override bindILinker() {
		return MitaLinker
	}
	
	override bindXtextResource() {
		return MitaBaseResource;
	}
	
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
