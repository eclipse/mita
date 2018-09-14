package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@EqualsHashCode
@Accessors
class TypeVariableProxy extends TypeVariable {
	static Integer instanceCount = 0;
	protected final EReference reference;
	
	new(EObject origin, EReference reference) {
		super(origin, '''p_«instanceCount++»''')
		this.reference = reference;
	}
		
}