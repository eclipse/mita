package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject

class AtomicType extends AbstractType {
	protected static Integer instanceCount = 0;
	
	new(EObject origin) {
		super(origin, '''atom_«instanceCount++»''');
	}
	
	new(EObject origin, String name) {
		super(origin, name);
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return this;
	}
	
	override getFreeVars() {
		return #[];
	}
		
}