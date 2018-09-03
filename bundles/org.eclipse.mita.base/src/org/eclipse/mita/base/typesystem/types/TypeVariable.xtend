package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.mita.base.typesystem.solver.Substitution

@FinalFieldsConstructor
@EqualsHashCode
class TypeVariable extends AbstractType {
	static Integer instanceCount = 0;
	
	new(EObject origin) {
		super(origin, '''f_«instanceCount++»''')
	}
	
	override toString() {
		name
	}
	
	override getFreeVars() {
		return #[this];
	}
	
	override AbstractType replace(TypeVariable from, AbstractType with) {
		return if(from == this) {
			with;
		} 
		else {
			this;	
		}
	}
	
	override toGraphviz() {
		return "";
	}
	
	override replace(Substitution sub) {
		sub.substitutions.getOrDefault(this, this);
	}
	
}
