package org.eclipse.mita.base.typesystem.infra

import org.eclipse.mita.base.typesystem.ITypeProvider
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.typesystem.types.BottomType

class TypeProviderImpl implements ITypeProvider {
	
	override getType(EObject obj) {
		val typeVar = TypeVariableAdapter.get(obj);
		val resourceSet = obj.eResource.resourceSet;
		if(resourceSet instanceof MitaResourceSet) {
			val result = resourceSet.latestSolution?.solution?.apply(typeVar);
			if(!(result instanceof TypeVariable)) {
				return result;
			}
		} else {
			throw new UnsupportedOperationException("Cannot retrieve types from anything but a MitaResourceSet");
		}
		
		return new BottomType(obj, "Unable to infer concrete valid type");
	}
	
}