package org.eclipse.mita.base.typesystem.types

import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor
@EqualsHashCode
@Accessors
class TypeHole extends TypeVariable {
	
	override getFreeVars() {
		return #[];
	}
	
	override modifyNames((String) => String converter) {
		return new TypeHole(origin, converter.apply(name))
	}
}