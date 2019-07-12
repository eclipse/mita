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
import org.eclipse.mita.base.types.TypeReferenceSpecifier
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType

class OptionalSizeInferrer extends GenericContainerSizeInferrer {
	
	override getDataTypeIndexes() {
		return #[1];
	}
	
	override getSizeTypeIndexes() {
		return #[];
	}	
	
	dispatch override Pair<AbstractType, Iterable<EObject>> doUnbindSize(Resource r, ConstraintSystem system, TypeReferenceSpecifier typeSpecifier, TypeConstructorType type) {
		return setTypeArguments(type, 
			[i, t| 
				delegate.unbindSize(r, system, if(typeSpecifier.typeArguments.size > i) {typeSpecifier.typeArguments.get(i - 1)}, t)
			], 
			[i, t| system.newTypeVariable(t.origin) as AbstractType -> #[typeSpecifier.typeArguments.get(i - 1)] + typeSpecifier.typeArguments.get(i - 1).eAllContents.toIterable],
			[t_objs | t_objs.key],
			[t, objs| t -> objs.flatMap[it.value]]
		);
	}
}