package org.eclipse.mita.base.typesystem.types

import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@EqualsHashCode
class ProdType extends AbstractType {
	private static Integer instanceCount = 0;
	
	protected final List<AbstractType> types;
	
	new(EObject origin, List<AbstractType> types) {
		super(origin, '''prod_«instanceCount++»''');
		this.types = types;
	}
	
	override toString() {
		"(" + types.join(", ") + ")"
	}
	
	override replace(TypeVariable from, AbstractType with) {
		new ProdType(origin, types.map[ it.replace(from, with) ]);
	}
	
	override getFreeVars() {
		return types.filter(TypeVariable);
	}
}