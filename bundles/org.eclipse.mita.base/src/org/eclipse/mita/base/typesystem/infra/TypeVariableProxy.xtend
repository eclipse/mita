package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@EqualsHashCode
@Accessors
class TypeVariableProxy extends TypeVariable {
	static Integer instanceCount = 0;
	
	// name of the origin member we want to resolve
	protected final String reference;
	
	new(EObject origin, String reference) {
		super(origin, '''p_«instanceCount++»''')
		this.reference = reference;
	}
	
	new(EObject origin, String name, String reference) {
		super(origin, name)
		this.reference = reference;
	}
		
}