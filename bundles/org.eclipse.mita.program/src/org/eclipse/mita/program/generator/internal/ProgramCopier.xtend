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

import org.eclipse.mita.program.Program
import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl
import org.eclipse.emf.ecore.util.EcoreUtil.Copier

class ProgramCopier {

	private static class CopySourceAdapter extends AdapterImpl {
		private final EObject origin;
		
		new(EObject origin) {
			this.origin = origin;
		}
		
		def getOrigin() {
			origin;
		}
	}

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
		val set = new ResourceSetImpl
		val res = set.createResource(original.eResource.URI)
		res.contents.add(copy);
	}
	
	def void linkOrigin(EObject copy, EObject origin) {
		copy.eAdapters.add(new CopySourceAdapter(origin));
	}
	
	def EObject getOrigin(EObject obj) {
		computeOrigin(obj);
	}
	
	static def EObject computeOrigin(EObject obj) {
		val adapter = obj.eAdapters.filter(CopySourceAdapter).head;
		return if(adapter === null) {
			obj;
		} else {
			computeOrigin(adapter.getOrigin());
		}
	}
}
