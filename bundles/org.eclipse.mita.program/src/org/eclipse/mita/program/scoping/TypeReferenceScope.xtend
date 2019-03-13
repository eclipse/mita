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

package org.eclipse.mita.program.scoping

import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.scoping.IScope
import org.eclipse.xtext.scoping.Scopes
import java.util.ArrayList
import org.eclipse.xtext.scoping.impl.AbstractScope
import org.eclipse.mita.base.types.GenericElement

import static extension org.eclipse.xtext.EcoreUtil2.*
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.mita.program.Program
import org.eclipse.xtext.resource.IEObjectDescription

class TypeReferenceScope extends AbstractScope {
	
	EObject context

	new(IScope outer, EObject context) {
		super(outer, false)
		this.context = context
	}
	
	override protected getAllLocalElements() {
		var result = newArrayList()
		result.addTypeParameter(context)
		result.addLocalTypes()
		Scopes.scopedElementsFor(result)
	}
	
	def void addLocalTypes(ArrayList<EObject> result) {
		val program = EcoreUtil2.getContainerOfType(context, Program);
		if(program !== null) {
			result += program.types.filter[ProgramDslScopeProvider.globalTypeFilter.apply(it.eClass)]; 
		}
	}
	
	def void addTypeParameter(ArrayList<EObject> result, EObject object) {
		var prev = object;
		var container = object.getContainerOfType(GenericElement);
		while (container !== null && container !== prev) {
			result.addTypeParameter(if(object === container) container.eContainer else container);
			result += container.typeParameters
			prev = container;
			container = object.getContainerOfType(GenericElement)
		}
	}
	
}