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

package org.eclipse.mita.cli.loader

import com.google.inject.AbstractModule
import org.eclipse.mita.base.scoping.ILibraryProvider
import org.eclipse.mita.base.scoping.TypesGlobalScopeProvider
import org.eclipse.mita.program.generator.ProgramDslGenerator
import org.eclipse.mita.program.resource.PluginResourceLoader

class StandaloneModule extends AbstractModule {
	
	override protected configure() {
		bind(TypesGlobalScopeProvider).to(StandaloneTypesGlobalScopeProvider);
		bind(ILibraryProvider).toInstance(StandaloneLibraryProvider.getInstance());
		bind(ProgramDslGenerator).to(StandaloneProgramDslGenerator);
		bind(PluginResourceLoader).to(StandalonePluginResourceLoader);
	}
	
}