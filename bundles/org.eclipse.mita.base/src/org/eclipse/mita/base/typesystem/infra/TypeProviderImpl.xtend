package org.eclipse.mita.base.typesystem.infra

import org.eclipse.mita.base.typesystem.ITypeProvider
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.typesystem.types.BottomType

class TypeProviderImpl implements ITypeProvider {
	
	override getType(EObject obj) {
		val resourceSet = obj.eResource.resourceSet;
		if(resourceSet instanceof MitaResourceSet) {
			val solution = resourceSet.latestSolution;
			val system = solution?.getConstraintSystem;
			val typeVar = system?.getTypeVariable(obj);
			val result = solution?.solution?.apply(typeVar);
			if(!(result instanceof TypeVariable)) {
				return result;
			}
		} else {
			throw new UnsupportedOperationException("Cannot retrieve types from anything but a MitaResourceSet");
		}
		
		return new BottomType(obj, "Unable to infer concrete valid type");
	}
	
}