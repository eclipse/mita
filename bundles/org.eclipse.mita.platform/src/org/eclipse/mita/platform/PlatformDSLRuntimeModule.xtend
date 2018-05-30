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
import org.eclipse.mita.base.expressions.inferrer.ExpressionsTypeInferrer
import org.eclipse.mita.base.scoping.MitaTypeSystem
import org.eclipse.mita.base.scoping.TypesGlobalScopeProvider
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer
import org.eclipse.mita.base.types.typesystem.ITypeSystem
import org.eclipse.mita.platform.scoping.PlatformDslImportScopeProvider
import org.eclipse.mita.platform.scoping.PlatformDslResourceDescriptionStrategy
import org.eclipse.xtext.resource.IDefaultResourceDescriptionStrategy
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.xtext.scoping.impl.AbstractDeclarativeScopeProvider
import org.eclipse.xtext.service.DefaultRuntimeModule

class PlatformDSLRuntimeModule extends AbstractPlatformDSLRuntimeModule {

	override configure(Binder binder) {
		super.configure(binder)
		binder.bind(ITypeSystem).toInstance(MitaTypeSystem.getInstance())
		binder.bind(ITypeSystemInferrer).to(ExpressionsTypeInferrer)
		binder.bind(IDefaultResourceDescriptionStrategy).to(PlatformDslResourceDescriptionStrategy)
		binder.bind(DefaultRuntimeModule).annotatedWith(Names.named("injectingModule")).toInstance(this)
	}

	override bindIGlobalScopeProvider() {
		TypesGlobalScopeProvider
	}
	
	override configureIScopeProviderDelegate(Binder binder) {
		binder.bind(IScopeProvider)
                .annotatedWith(Names
                        .named(AbstractDeclarativeScopeProvider.NAMED_DELEGATE))
                .to(PlatformDslImportScopeProvider);
	}

}
