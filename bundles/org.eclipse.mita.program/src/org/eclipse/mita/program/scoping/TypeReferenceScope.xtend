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
import org.yakindu.base.types.GenericElement

import static extension org.eclipse.xtext.EcoreUtil2.*

class TypeReferenceScope extends AbstractScope {
	
	EObject context

	new(IScope outer, EObject context) {
		super(outer, false)
		this.context = context
	}
	
	override protected getAllLocalElements() {
		var result = newArrayList()
		result.addTypeParameter(context)
		Scopes.scopedElementsFor(result)
	}
	
	def addTypeParameter(ArrayList<EObject> result, EObject object) {
		val container = object.getContainerOfType(GenericElement)
		if (container !== null)
			result += container.typeParameters
	}
	
}