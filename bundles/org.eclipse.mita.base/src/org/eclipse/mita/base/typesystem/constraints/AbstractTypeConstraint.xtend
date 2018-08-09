package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable

abstract class AbstractTypeConstraint {
	
	abstract def AbstractTypeConstraint replace(TypeVariable from, AbstractType with);
	
	abstract def Iterable<TypeVariable> getActiveVars();
	
	abstract def Iterable<EObject> getOrigins();
	
	/**
	 * @return all types involved in this constraint
	 */
	abstract def Iterable<AbstractType> getTypes();
	
	abstract def String toGraphviz();
	
}
