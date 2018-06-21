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
import com.google.inject.Provider
import org.eclipse.xtext.resource.IResourceServiceProvider
import org.eclipse.xtext.resource.impl.ResourceServiceProviderRegistryImpl
import org.eclipse.xtext.resource.IExternalContentSupport

class StandanloneLangServerModule extends AbstractModule {
	
	override protected configure() {
		bind(IResourceServiceProvider.Registry).toProvider(StandaloneResourceServiceProviderLoader);
		bind(IExternalContentSupport).to(LspExternalContentSupport);
	}
	
}

class StandaloneResourceServiceProviderLoader implements Provider<IResourceServiceProvider.Registry> {
	
	override get() {
		val registry = new ResourceServiceProviderRegistryImpl();
		for(entry: IResourceServiceProvider.Registry.INSTANCE.extensionToFactoryMap.entrySet) {
			registry.extensionToFactoryMap.put(entry.key, entry.value);
		}
 		return registry;
	}
	
}