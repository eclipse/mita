package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy

@FinalFieldsConstructor
@Accessors
@EqualsHashCode
class JavaClassInstanceConstraint extends AbstractTypeConstraint {
	
	protected val AbstractType what;
	protected val Class<?> javaClass;
	
	override replace(TypeVariable from, AbstractType with) {
		return new JavaClassInstanceConstraint(what.replace(from, with), javaClass);
	}
	
	override replace(Substitution sub) {
		return new JavaClassInstanceConstraint(what.replace(sub), javaClass);
	}
	
	override getActiveVars() {
		return what.freeVars;
	}
	
	override getOrigins() {
		return #[what.origin];
	}
	
	override getTypes() {
		return #[what];
	}
	
	override toGraphviz() {
		return what.toGraphviz;
	}
	
	override replaceProxies((TypeVariableProxy)=>AbstractType resolve) {
		return new JavaClassInstanceConstraint(what.replaceProxies(resolve), javaClass);
	}
	
}