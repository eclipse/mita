package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.typesystem.types.TypeVariableProxy
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor
@EqualsHashCode
@Accessors
abstract class AbstractTypeConstraint {
	
	// You can use a format string as message to use final inferred types
	// java strings allow argument reuse with positional formatters like "%2$s" <-> second argument as string
	val ValidationIssue _errorMessage;
	def getErrorMessage() {
		return _errorMessage;	
	}
	
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
	
	abstract def boolean isAtomic(ConstraintSystem system);
	
	def AbstractTypeConstraint replaceProxies(ConstraintSystem system, (TypeVariableProxy) => Iterable<AbstractType> resolve) {
		return map[it.replaceProxies(system, resolve)]
	}
	
	def AbstractTypeConstraint modifyNames((String) => String converter) {
		return map[it.modifyNames(converter)]
	}
}
