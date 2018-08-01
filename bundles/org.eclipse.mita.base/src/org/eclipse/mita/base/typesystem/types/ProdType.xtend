package org.eclipse.mita.base.typesystem.types

import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.Accessors

@EqualsHashCode
@Accessors
class ProdType extends AbstractType {	
	protected final List<AbstractType> types;
	
	new(EObject origin, List<AbstractType> types) {
		super(origin, '''prod''');
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