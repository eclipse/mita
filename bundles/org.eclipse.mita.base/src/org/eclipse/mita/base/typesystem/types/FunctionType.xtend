package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import static extension org.eclipse.mita.base.util.BaseUtils.force
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem

@EqualsHashCode
@Accessors
@FinalFieldsConstructor
class FunctionType extends TypeConstructorType {		
	new(EObject origin, String cons, AbstractType from, AbstractType to) {
		super(origin, cons, #[from, to]);
		if(from === null || to === null) {
			throw new NullPointerException;
		}
	}
	
	def AbstractType getFrom() {
		return typeArguments.get(0);
	}
	def AbstractType getTo() {
		return typeArguments.get(1);
	}
	
	override toString() {
		from + " → " + to
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
	
	override expand(ConstraintSystem system, Substitution s, TypeVariable tv) {
		val newFType = new FunctionType(origin, name, system.newTypeVariable(from.origin), system.newTypeVariable(to.origin));
		s.add(tv, newFType);
	}
	
	override toGraphviz() {
		'''"«to»" -> "«this»"; "«this»" -> "«from»"; «to.toGraphviz» «from.toGraphviz»''';
	}
	


	
	override map((AbstractType)=>AbstractType f) {
		return new FunctionType(origin, name, typeArguments.map[it.map(f)].force, superTypes);
	}
	
}