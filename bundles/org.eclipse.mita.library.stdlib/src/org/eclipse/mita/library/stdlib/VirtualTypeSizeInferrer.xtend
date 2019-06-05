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

package org.eclipse.mita.library.stdlib

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.typesystem.infra.ElementSizeInferrer
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType

class VirtualTypeSizeInferrer implements ElementSizeInferrer {
	
	override infer(ConstraintSystem system, Substitution sub, Resource r, EObject obj, AbstractType type) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override setDelegate(ElementSizeInferrer delegate) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
		
}