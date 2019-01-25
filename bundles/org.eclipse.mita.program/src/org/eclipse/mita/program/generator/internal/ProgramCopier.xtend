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

package org.eclipse.mita.program.generator.internal

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.util.EcoreUtil.Copier
import org.eclipse.mita.base.typesystem.infra.MitaResourceSet
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.base.util.CopySourceAdapter
import org.eclipse.mita.program.Program

class ProgramCopier {
	
	@Inject
	Provider<MitaResourceSet> resourceSetProvider;
	
	def copy(Program program) {
		val copier = new Copier();
		val copy = copier.copy(program) as Program;
		copier.copyReferences();
		copier.forEach[
			o, c | c.linkOrigin(o)
		]
		
		createPseudoResource(program, copy)
		
		return copy;
	}
	
	protected def createPseudoResource(Program original, Program copy) {
		val set = resourceSetProvider.get;
		val res = set.createResource(original.eResource.URI);
		res.contents.add(copy);
		set.getResource(original.eResource.URI, true);
	}
	
	def void linkOrigin(EObject copy, EObject origin) {
		copy.eAdapters.add(new CopySourceAdapter(origin));
	}
	
	static def EObject getOrigin(EObject obj) {
		BaseUtils.computeOrigin(obj);
	}
	
}
