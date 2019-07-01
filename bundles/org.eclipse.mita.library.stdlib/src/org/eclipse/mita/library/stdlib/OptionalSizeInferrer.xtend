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
import org.eclipse.mita.base.typesystem.infra.InferenceContext

class OptionalSizeInferrer extends GenericContainerSizeInferrer {
	
	override getDataTypeIndexes() {
		return #[1];
	}
	
	override getSizeTypeIndexes() {
		return #[];
	}	
	
	def getInnerSpecifier(TypeReferenceSpecifier specifier) {
		if(specifier.optional) {
			return specifier;
		}
		return specifier.typeArguments.get(0);
	}
	
	dispatch override Pair<AbstractType, Iterable<EObject>> doUnbindSize(Resource r, ConstraintSystem system, TypeReferenceSpecifier typeSpecifier, TypeConstructorType type) {
		return setTypeArguments(type, 
			[i, t| 
				delegate.unbindSize(r, system, typeSpecifier.innerSpecifier, t)
			], 
			[i, t| system.newTypeVariable(t.origin) as AbstractType -> #[typeSpecifier.innerSpecifier] + typeSpecifier.innerSpecifier.eAllContents.toIterable],
			[t_objs | t_objs.key],
			[t, objs| t -> objs.flatMap[it.value]]
		);
	}
	
	dispatch override void doCreateConstraints(InferenceContext c, TypeReferenceSpecifier obj, TypeConstructorType t) {
		if(obj.optional) {
			val modelType = obj.innerSpecifier;
			val innerContext = new InferenceContext(c, modelType, c.system.getTypeVariable(modelType), t.typeArguments.get(1)); 
			delegate.createConstraints(innerContext);
		}
		else {
			val newType = setTypeArguments(t, [i, t1| 
				val modelType = obj.innerSpecifier;
				val innerContext = new InferenceContext(c, modelType, c.system.getTypeVariable(modelType), t1);
				delegate.createConstraints(innerContext);
				val result = c.system.newTypeVariable(t1.origin) as AbstractType
				c.system.associate(result, modelType)
				result;
			], [i, t1|
				// no size arguments in optionals
				t1;
			], [it], [t1, xs | t1])
			c.system.associate(newType, obj);
		}
	}
}