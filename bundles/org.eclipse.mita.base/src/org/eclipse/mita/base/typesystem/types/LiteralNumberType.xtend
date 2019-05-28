package org.eclipse.mita.base.typesystem.types

import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem

@Accessors
class LiteralNumberType extends AbstractBaseType implements LiteralTypeExpression<Long> {
	val long value;
	val AbstractType typeOf;
	
	new(EObject origin, String name, long value, AbstractType typeOf) {
		super(origin, name)
		this.value = value;
		this.typeOf = typeOf;
	}
	
	override getFreeVars() {
		return typeOf.freeVars
	}
	
	override eval() {
		return value;
	}
	
	override simplify() {
		return this;
	}
	
	override replace(Substitution sub) {
		val newTypeOf = typeOf.replace(sub);
		if(newTypeOf !== typeOf) {
			return new LiteralNumberType(origin, name, value, typeOf);
		}
		return this;
	}
	
	override replace(TypeVariable from, AbstractType with) {
		val newTypeOf = typeOf.replace(from, with);
		if(newTypeOf !== typeOf) {
			return new LiteralNumberType(origin, name, value, typeOf);
		}
		return this;
	}
	
	override replaceProxies(ConstraintSystem system, (TypeVariableProxy)=>Iterable<AbstractType> resolve) {
		val newTypeOf = typeOf.replaceProxies(system, resolve);
		if(newTypeOf !== typeOf) {
			return new LiteralNumberType(origin, name, value, typeOf);
		}
		return this;
	}
}