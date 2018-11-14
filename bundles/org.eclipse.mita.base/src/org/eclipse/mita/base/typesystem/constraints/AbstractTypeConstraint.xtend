package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.Accessors

@FinalFieldsConstructor
@EqualsHashCode
@Accessors
abstract class AbstractTypeConstraint {
	
	// TODO: make this (AbstractTypeConstraint) => String to allow more inspection
	val String errorMessage;
	
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
	
	def String getOperator();
	
	def Iterable<Object> getMembers() {
		return getTypes().map[it];
	}
	
	abstract def String toGraphviz();
	
	abstract def boolean isAtomic();
	
	def AbstractTypeConstraint replaceProxies((TypeVariableProxy) => AbstractType resolve) {
		return map[it.replaceProxies(resolve)]
	}
	
	def AbstractTypeConstraint modifyNames(String suffix) {
		return map[it.modifyNames(suffix)]
	}
}
