package org.eclipse.mita.base.typesystem.types

import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@FinalFieldsConstructor
@EqualsHashCode
class AtomicType extends AbstractType {
	protected static Integer instanceCount = 0;
	protected final List<AbstractType> freeVars;
	
	
	new(EObject origin) {
		this(origin,  '''atom_«instanceCount++»''');
	}
	
	new(EObject origin, String name) {
		this(origin, name, #[]);
	}
	
	override replace(TypeVariable from, AbstractType with) {
		val newVars = freeVars.map[it.replace(from, with)]
		return new AtomicType(origin, name, newVars);
	}
	
	override getFreeVars() {
		return freeVars.flatMap[it.freeVars];
	}
		
}