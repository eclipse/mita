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
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.mita.cli.commands.CompileCommand
import org.eclipse.xtext.resource.ExternalContentSupport

class LspExternalContentSupport extends ExternalContentSupport {
	
	override configureResourceSet(ResourceSet resourceSet, IExternalContentProvider contentProvider) {
		super.configureResourceSet(resourceSet, contentProvider)
		
		val allFilesInClasspath = CompileCommand.getAllMitaAndPlatformFilesInClasspath();
		for(libraryFile : allFilesInClasspath) {
			println("Loading " + libraryFile);
			resourceSet.getResource(URI.createURI(libraryFile), true);
		}
		EcoreUtil.resolveAll(resourceSet);
	}
	
}