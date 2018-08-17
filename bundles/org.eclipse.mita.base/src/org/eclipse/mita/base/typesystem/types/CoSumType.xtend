package org.eclipse.mita.base.typesystem.types

import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

import static extension org.eclipse.mita.base.util.BaseUtils.force

@FinalFieldsConstructor
@EqualsHashCode
class CoSumType extends ProdType {
	
	override replace(TypeVariable from, AbstractType with) {
		new CoSumType(origin, name, superTypes, types.map[ it.replace(from, with) ].force);
	}
	override void expand(Substitution s, TypeVariable tv) {
		val newTypeVars = types.map[ new TypeVariable(it.origin) as AbstractType ].force;
		val newPType = new CoSumType(origin, name, superTypes, newTypeVars);
		s.add(tv, newPType);
	}
}