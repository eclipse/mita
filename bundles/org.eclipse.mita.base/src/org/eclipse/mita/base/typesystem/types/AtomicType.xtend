package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.mita.base.typesystem.solver.Substitution

@EqualsHashCode
class AtomicType extends AbstractBaseType {
		
	new(EObject origin, String name) {
		super(origin, name)
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return this;
	}
	
	override getFreeVars() {
		return #[]
	}
	
	override replace(Substitution sub) {
		return this;
	}
	
	override map((AbstractType)=>AbstractType f) {
		return this;
	}
		
}