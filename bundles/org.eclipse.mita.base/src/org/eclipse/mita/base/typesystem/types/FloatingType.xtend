package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.Accessors

@EqualsHashCode
@Accessors
class FloatingType extends NumericType {
	new(EObject origin, int widthInBytes) {
		super(origin, '''f«widthInBytes * 8»''', widthInBytes);
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return this;
	}
	
	override replace(Substitution sub) {
		return this;
	}
	
	override getFreeVars() {
		return #[];
	}
	
}