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

import org.eclipse.mita.base.typesystem.infra.InferenceContext
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.constraints.MaxConstraint
import org.eclipse.mita.base.typesystem.infra.TypeSizeInferrer
import org.eclipse.mita.program.ReferenceExpression
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.program.DereferenceExpression

class ReferenceSizeInferrer extends GenericContainerSizeInferrer {
	
	override getDataTypeIndexes() {
		return #[1];
	}
	
	override getSizeTypeIndexes() {
		return #[];
	}
	
	override unbindSize(Resource r, ConstraintSystem system, EObject obj, AbstractType type) {
		super.unbindSize(r, system, obj, type)
	}
	
	dispatch def void doCreateConstraints(InferenceContext c, ReferenceExpression expr, AbstractType t) {	
		print("")
	}
	dispatch def void doCreateConstraints(InferenceContext c, DereferenceExpression expr, AbstractType t) {	
		print("")
	}
	
}