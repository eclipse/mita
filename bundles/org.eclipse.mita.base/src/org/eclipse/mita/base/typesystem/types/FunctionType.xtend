package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.Accessors

@EqualsHashCode
@Accessors
class FunctionType extends AbstractType {	
	protected final AbstractType from;
	protected final AbstractType to;
	
	new(EObject origin, AbstractType from, AbstractType to) {
		super(origin, '''fun''');
		this.from = from;
		this.to = to;
	}
	
	override toString() {
		from + " → " + to
	}
	
	override replace(TypeVariable from, AbstractType with) {
		new FunctionType(origin, this.from.replace(from, with), this.to.replace(from, with));
	}
	
	override getFreeVars() {
		return #[from, to].filter(TypeVariable);
	}	
}