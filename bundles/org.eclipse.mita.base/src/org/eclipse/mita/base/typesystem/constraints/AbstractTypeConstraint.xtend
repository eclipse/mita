package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable

abstract class AbstractTypeConstraint {
	
	abstract def AbstractTypeConstraint map((AbstractType) => AbstractType f);

	def AbstractTypeConstraint replace(TypeVariable from, AbstractType with) {
		return map[it.replace(from, with)];
	}

	def AbstractTypeConstraint replace(Substitution sub) {
		return map[it.replace(sub)];
	}
	
	abstract def Iterable<TypeVariable> getActiveVars();
	
	abstract def Iterable<EObject> getOrigins();
	
	/**
	 * @return all types involved in this constraint
	 */
	abstract def Iterable<AbstractType> getTypes();
	
	abstract def String toGraphviz();
	
	
	def AbstractTypeConstraint replaceProxies((TypeVariableProxy) => AbstractType resolve) {
		return map[it.replaceProxies(resolve)]
	}
	
	def AbstractTypeConstraint modifyNames(String suffix) {
		return map[it.modifyNames(suffix)]
	}
}
