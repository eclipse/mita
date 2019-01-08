package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor
@Accessors
@EqualsHashCode
class JavaClassInstanceConstraint extends AbstractTypeConstraint {
	
	protected val AbstractType what;
	protected val Class<?> javaClass;
	
	override getErrorMessage() {
		return new ValidationIssue(_errorMessage, String.format(_errorMessage.message, what, javaClass));
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
		val newWhat = what.map(f);
		if(what !== newWhat) {
			return new JavaClassInstanceConstraint(_errorMessage, what.map(f), javaClass);
		}
		return this;
	}
	override getOperator() {
		return "java instanceof"
	}
	
	override isAtomic(ConstraintSystem system) {
		return what instanceof TypeVariable
	}
	
}