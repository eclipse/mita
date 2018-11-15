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
	
	override modifyNames(String suffix) {
		return new TypeHole(origin, name + suffix)
	}
}