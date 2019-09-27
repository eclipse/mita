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

import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.mita.base.scoping.ILibraryProvider
import org.eclipse.mita.cli.commands.CompileToCAdapter

/*
 * In a standalone context we cannot register libraries like we do in an Eclipse setting.
 * For now we use a single resource set as library registry. This library provider contains
 * this resource set and is bound as singleton in the standalone compiler module.
 */
class StandaloneLibraryProvider implements ILibraryProvider {
	protected ResourceSet resourceSet;

	static ILibraryProvider instance = new StandaloneLibraryProvider();
	
	static def ILibraryProvider getInstance() {
		return instance;
	}

	protected new() { }

	def init(ResourceSet resourceSet) {
		this.resourceSet = resourceSet;
	}

	protected def getAllLibraries() {
		if(resourceSet === null) {
			return #[]
		} else {
			return resourceSet.
				resources.
				filter[ 
					!it.eAdapters.exists[ 
						it instanceof CompileToCAdapter
					]
				]
				.map[ it.URI ];			
		}
		
	}
	
	override getLibraries() {
		return allLibraries.reject[ isStdlib ]
	}
	
	override getStandardLibraries() {
		return allLibraries.filter[ isStdlib ]
	}
	
	protected def isStdlib(URI uri) {
		return uri.lastSegment.startsWith("stdlib_");
	}
	
}