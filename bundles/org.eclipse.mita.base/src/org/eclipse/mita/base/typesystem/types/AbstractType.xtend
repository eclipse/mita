package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@Accessors
@EqualsHashCode
abstract class AbstractType {
	protected final EObject origin;
	protected final String name;
	
	abstract def AbstractType replace(AbstractType from, AbstractType with);
	
	abstract def Iterable<TypeVariable> getFreeVars();
	
}