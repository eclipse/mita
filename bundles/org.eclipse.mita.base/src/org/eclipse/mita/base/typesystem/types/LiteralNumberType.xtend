package org.eclipse.mita.base.typesystem.types

import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.infra.SubtypeChecker

@Accessors
class LiteralNumberType extends AbstractBaseType implements PrimitiveLiteralType<Long> {
	val long value;
	val AbstractType typeOf;
	
	new(EObject origin, long value, AbstractType typeOf) {
		super(origin, "'" + String.valueOf(value))
		this.value = value;
		this.typeOf = typeOf;
	}
		
	override eval() {
		return value;
	}
	
	override simplify() {
		return this;
	}
	
	override map((AbstractType)=>AbstractType f) {
		val newTypeOf = typeOf.map(f);
		if(newTypeOf !== typeOf) {
			return new LiteralNumberType(origin, value, newTypeOf);
		}
		return this;
	}
	
	override decompose() {
		return this -> #[];
	}
		
	override getFreeVars() {
		return typeOf?.freeVars ?: #[];
	}
	
	override getTypeArgument() {
		return Long;
	}
	
}