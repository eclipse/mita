package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@Accessors
abstract class AbstractType {
	
	protected final transient EObject origin;
	protected final String name;
	
	abstract def AbstractType map((AbstractType) => AbstractType f);
	
	override boolean equals(Object other) {
		if (this === other)
		  return true;
		if (other === null)
		  return false;
		if (getClass() !== other.getClass())
		  return false;
		return name == (other as AbstractType).name;
	}
	
	override hashCode() {
		return name.hashCode();
	}
	
	def AbstractType replace(TypeVariable from, AbstractType with) {
		map[it.replace(from, with)];
	}
	
	def AbstractType replace(Substitution sub) {
		map[it.replace(sub)];
	}
	
	def Pair<Iterable<TypeVariable>, AbstractType> instantiate(ConstraintSystem system) {
		return #[] -> this;
	}
	
	abstract def Iterable<TypeVariable> getFreeVars();
	
	override toString() {
		name
	}
	
	def generalize(ConstraintSystem system) {
		return new TypeScheme(origin, freeVars.toList, this);
	}
	
	abstract def String toGraphviz();
	
	def AbstractType replaceProxies((TypeVariableProxy) => AbstractType resolve) {
		map[it.replaceProxies(resolve)];
	}
	
	def AbstractType modifyNames(String suffix) {
		map[it.modifyNames(suffix)];
	}
}