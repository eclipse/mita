package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.InstanceTypeParameter
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem

@Accessors
class DependentTypeVariable extends TypeVariable {
	/**
	 * This type variable is created on translating @link InstanceTypeParameter.
	 * instantiating this type variable neccessitates a subtype constraint on its dependsOn member.
	 * dependsOn must be able to hold a value of the type being instantiated.
	 */
	protected val AbstractType dependsOn;
	
	new(EObject origin, int idx, AbstractType dependsOn) {
		this(origin, idx, null, dependsOn);
	}
	
	new(EObject origin, int idx, String name, AbstractType dependsOn) {
		super(origin, idx, name)
		this.dependsOn = dependsOn;
	}
	
	override modifyNames(NameModifier converter) {
		val newName = converter.apply(idx);
		if(newName instanceof Left<?, ?>) {
			return new DependentTypeVariable(origin, (newName as Left<Integer, String>).value, name, dependsOn);
		}
		else {
			return new DependentTypeVariable(origin, idx, (newName as Right<Integer, String>).value, dependsOn);
		}
	}
	
	override replaceProxies(ConstraintSystem system, (TypeVariableProxy)=>Iterable<AbstractType> resolve) {
		val newDependsOn = dependsOn.replaceProxies(system, resolve);
		if(newDependsOn !== dependsOn) {
			return new DependentTypeVariable(origin, idx, name, newDependsOn);
		}
		return this;
	}
	
	override protected getToStringPrefix() {
		return 'd_'
	}
	
	override getFreeVars() {
		return #[this] + dependsOn.freeVars
	}
	
}