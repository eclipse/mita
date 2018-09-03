package org.eclipse.mita.base.typesystem.types

import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.solver.Substitution

@FinalFieldsConstructor
@Accessors
@EqualsHashCode
class BottomType extends AbstractBaseType {
	protected final String message;
	
	override replace(TypeVariable from, AbstractType with) {
		return this;
	}
	
	new(EObject origin, String message) {
		super(origin, "⊥")
		this.message = message;
	}
	
	override getFreeVars() {
		return #[];
	}
	
	override toString() {
		'''⊥ («message»)'''
	}
	
	override replace(Substitution sub) {
		return this;
	}
	
}