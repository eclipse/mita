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

import com.google.inject.Guice
import com.google.inject.Module
import com.google.inject.util.Modules
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.mita.program.generator.ProgramDslGenerator

class StandaloneProgramDslGenerator extends ProgramDslGenerator {
	
	
	
	override protected injectPlatformDependencies(Object obj, Module libraryModule) {
		injector = Guice.createInjector(Modules.override(injectingModule).with(new StandaloneModule()), libraryModule);
		injector.injectMembers(obj);
	}
	
	override getUserFiles(ResourceSet set) {
		#[]
	}
	
}