package org.eclipse.mita.base.typesystem.types

import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.scoping.IScopeProvider

import static extension org.eclipse.mita.base.util.BaseUtils.force

@FinalFieldsConstructor
@EqualsHashCode
class CoSumType extends ProdType {
	
	override replace(TypeVariable from, AbstractType with) {
		new CoSumType(origin, name, typeArguments.map[ it.replace(from, with) ].force, superTypes);
	}
	override void expand(Substitution s, TypeVariable tv) {
		val newTypeVars = typeArguments.map[ new TypeVariable(it.origin) as AbstractType ].force;
		val newPType = new CoSumType(origin, name, newTypeVars, superTypes);
		s.add(tv, newPType);
	}
	
	override replace(Substitution sub) {
		new CoSumType(origin, name, typeArguments.map[ it.replace(sub) ].force, superTypes);
	}
	override replaceProxies(IScopeProvider scopeProvider) {
		return new CoSumType(origin, name, typeArguments.map[it.replaceProxies(scopeProvider) as AbstractType].force, superTypes);
	}
	
}