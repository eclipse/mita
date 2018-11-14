package org.eclipse.mita.base.typesystem.types

import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor
@EqualsHashCode
@Accessors
class BaseKind extends AbstractBaseType {
	
	val AbstractType kindOf;
	
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