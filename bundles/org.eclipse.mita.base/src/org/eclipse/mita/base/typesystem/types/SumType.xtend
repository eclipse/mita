package org.eclipse.mita.base.typesystem.types

import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.mita.base.typesystem.solver.Substitution

import static extension org.eclipse.mita.base.util.BaseUtils.force;

@EqualsHashCode
@Accessors
@FinalFieldsConstructor
class SumType extends TypeConstructorType {
	
	protected final List<AbstractType> types;
		
	override toString() {
		"(" + types.map[name].join(" | ") + ")"
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return new SumType(origin, name, superType, this.types.map[ it.replace(from, with) ].force);
	}
	
	override getFreeVars() {
		return types.filter(TypeVariable);
	}
	
	override getTypeArguments() {
		return types;
	}
	
	override getVariance(int typeArgumentIdx, AbstractType tau, AbstractType sigma) {
		return new SubtypeConstraint(tau, sigma);
	}
	
	override expand(Substitution s, TypeVariable tv) {
		val newTypeVars = types.map[ new TypeVariable(it.origin) as AbstractType ].force;
		val newSType = new SumType(origin, name, superType, newTypeVars);
		s.add(tv, newSType);
	}
	
}