package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@Accessors
@EqualsHashCode
abstract class AbstractType {
	protected final EObject origin;
	protected final String name;
	
	abstract def AbstractType replace(TypeVariable from, AbstractType with);
	
	def Pair<Iterable<TypeVariable>, AbstractType> instantiate() {
		return #[] -> this;
	}
	
	abstract def Iterable<TypeVariable> getFreeVars();
	
	override toString() {
		name
	}
	
}