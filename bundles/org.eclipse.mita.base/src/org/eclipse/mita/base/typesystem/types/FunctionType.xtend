package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@EqualsHashCode
class FunctionType extends AbstractType {
	private static Integer instanceCount = 0;
	
	protected final AbstractType from;
	protected final AbstractType to;
	
	new(EObject origin, AbstractType from, AbstractType to) {
		super(origin, '''fun_«instanceCount++»''');
		this.from = from;
		this.to = to;
	}
	
	override toString() {
		from + " → " + to
	}
	
	override replace(AbstractType from, AbstractType with) {
		new FunctionType(origin, this.from.replace(from, with), this.to.replace(from, with));
	}
	
	override getFreeVars() {
		return #[from, to].filter(TypeVariable);
	}
	
	override instantiate() {
		val nfrom = if(from instanceof TypeVariable) new TypeVariable(from.origin) else from;
		val nto = if(to instanceof TypeVariable) new TypeVariable(to.origin) else to;
		return new FunctionType(origin, nfrom, nto);
	}
	
}