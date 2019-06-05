package org.eclipse.mita.base.typesystem.types

import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.infra.SubtypeChecker

@Accessors
class LiteralNumberType extends AbstractBaseType implements PrimitiveLiteralType<Long> {
	val long value;
	
	new(EObject origin, long value) {
		super(origin, String.valueOf(value))
		this.value = value;
	}
		
	override eval(SubtypeChecker subtypeChecker, ConstraintSystem s, EObject typeResolutionOrigin) {
		return value;
	}
	
	override simplify(SubtypeChecker subtypeChecker, ConstraintSystem s, EObject typeResolutionOrigin) {
		return this;
	}
	
	override decompose(SubtypeChecker subtypeChecker, ConstraintSystem s, EObject typeResolutionOrigin) {
		return this -> #[];
	}
		
	override getFreeVars() {
		return #[];
	}
	
}