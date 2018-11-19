package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@Accessors
@EqualsHashCode
class EqualityConstraint extends AbstractTypeConstraint {
	protected final AbstractType left;
	protected final AbstractType right;

	new(AbstractType left, AbstractType right, ValidationIssue source) {
		super(source);
		this.left = left;
		this.right = right;
		if(this.toString == "f_52.0 ≡ f_47.0") {
			print("");
		}
	}

	override toString() {
		left + " ≡ " + right
	}
		
	override getActiveVars() {
		return left.freeVars + right.freeVars;
	}
	
	override getOrigins() {
		return #[left, right].map[ it.origin ];
	}
	
	override getTypes() {
		return #[left, right];
	}
	
	override toGraphviz() {
		return '''"«left»" -> "«right»" [dir=both]; «left.toGraphviz» «right.toGraphviz»''';
	}
			
	override map((AbstractType)=>AbstractType f) {
		val newL = left.map(f);
		val newR = right.map(f);
		if(left !== newL || right !== newR) {
			return new EqualityConstraint(newL, newR, errorMessage);
		} 
		return this;
	}
	
	override getOperator() {
		return "≡"
	}
	
	override isAtomic() {
		return false;
	}
	
}