package org.eclipse.mita.base.typesystem;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.mita.base.typesystem.types.AbstractType;
import org.eclipse.mita.base.typesystem.types.BottomType;

public interface ITypeProvider {

	/**
	 * Retrieves a concrete type for an EObject. If the underlying type system cannot compute a valid
	 * concrete type, we return a {@link BottomType} instead.
	 * 
	 * @param obj the object for which to retrieve the type
	 * @return the type for the object
	 */
	AbstractType getType(EObject obj);
	
}
