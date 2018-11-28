package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem

@EqualsHashCode
@Accessors
class BaseKind extends AbstractBaseType {
	
	val AbstractType kindOf;
	
	new(EObject origin, String name, AbstractType kindOf) {
		super(origin, name);
		this.kindOf = kindOf;
		if(name.contains("BMA280") || name.contains("string")) {
			print("");
		}
	}
	
	override map((AbstractType)=>AbstractType f) {
		val newKindOf = kindOf.map(f);
		if(newKindOf !== kindOf) {
			return new BaseKind(origin, name, newKindOf);
		}
		return this;
	}
	override replaceProxies(ConstraintSystem system, (TypeVariableProxy) => Iterable<AbstractType> resolve) {
		return new BaseKind(origin, name, kindOf.replaceProxies(system, resolve));
	}
	
	override modifyNames(String suffix) {
		return new BaseKind(origin, name, kindOf.modifyNames(suffix));
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return new BaseKind(origin, name, kindOf.replace(from, with));
	}
	
	override replace(Substitution sub) {
		return new BaseKind(origin, name, kindOf.replace(sub));
	}
	
	override getFreeVars() {
		return #[];
	}
	
	override toString() {
		return '''∗«IF kindOf instanceof TypeVariable»«name»«ELSE»«kindOf»«ENDIF»'''
	}
	
	override toGraphviz() {
		return toString;
	}
	
}