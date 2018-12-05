package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.infra.Tree
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem

/**
 * Base types are types without type variables (e.g. atomic types or integers)
 */
abstract class AbstractBaseType extends AbstractType {
	
	static def unify(ConstraintSystem system, Iterable<AbstractType> instances) {
		return system.newTypeVariable(null);
	}
	
	new(EObject origin, String name) {
		super(origin, name)
	}
		
	override toGraphviz() {
		return "";
	}
	
	override Tree<AbstractType> quote() {
		return new Tree(this);
	}
	
	override quoteLike(Tree<AbstractType> structure) {
		return quote();
	}
	
	override replaceProxies(ConstraintSystem system, (TypeVariableProxy) => Iterable<AbstractType> resolve) {
		return this;
	}
	
	override map((AbstractType)=>AbstractType f) {
		return f.apply(this);
	}
	
	override modifyNames(String suffix) {
		return this;
	}
	
	override unqote(Iterable<Tree<AbstractType>> children) {
		return this;
	}
	
}