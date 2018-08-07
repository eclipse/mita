package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@EqualsHashCode
@Accessors
@FinalFieldsConstructor
class FunctionType extends TypeConstructorType {	
	protected final AbstractType from;
	protected final AbstractType to;
	
	new(EObject origin, String cons, AbstractType from, AbstractType to) {
		super(origin, cons, null);
		this.from = from;
		this.to = to;
	}
	
	override toString() {
		from + " → " + to
	}
	
	override replace(TypeVariable from, AbstractType with) {
		new FunctionType(origin, name, superType, this.from.replace(from, with), this.to.replace(from, with));
	}
	
	override getFreeVars() {
		return #[from, to].filter(TypeVariable);
	}
	
	override getTypeArguments() {
		return #[from, to];
	}
	
	override getVariance(int typeArgumentIdx, AbstractType tau, AbstractType sigma) {
		if(typeArgumentIdx == 1) {
			return new SubtypeConstraint(tau, sigma);
		}
		else {
			// function arguments are contravariant
			return new SubtypeConstraint(sigma, tau);
		}
	}
	
	override expand(Substitution s, TypeVariable tv) {
		val newFType = new FunctionType(origin, name, new TypeVariable(from.origin), new TypeVariable(to.origin));
		s.add(tv, newFType);
	}
	

}