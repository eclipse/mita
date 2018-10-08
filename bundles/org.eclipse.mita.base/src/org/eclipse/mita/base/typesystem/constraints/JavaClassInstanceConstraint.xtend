package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import java.lang.reflect.TypeVariable

@FinalFieldsConstructor
@Accessors
@EqualsHashCode
class JavaClassInstanceConstraint extends AbstractTypeConstraint {
	
	protected val AbstractType what;
	protected val Class<?> javaClass;
	
	override getActiveVars() {
		return what.freeVars;
	}
	
	override getOrigins() {
		return #[what.origin];
	}
	
	override getTypes() {
		return #[what];
	}
	
	override getMembers() {
		#[what, javaClass.simpleName]
	}
	
	override toGraphviz() {
		return what.toGraphviz;
	}
	
	override toString() {
		return '''«what» instanceof «javaClass.simpleName»''';
	}
	
	override map((AbstractType)=>AbstractType f) {
		return new JavaClassInstanceConstraint(what.map(f), javaClass);
	}
	override getOperator() {
		return "java instanceof"
	}
	
	override isAtomic() {
		return what instanceof TypeVariable
	}
	
}