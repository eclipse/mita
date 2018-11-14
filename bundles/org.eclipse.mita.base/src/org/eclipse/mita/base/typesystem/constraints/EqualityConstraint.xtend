package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.mita.base.util.BaseUtils

@Accessors
@EqualsHashCode
class EqualityConstraint extends AbstractTypeConstraint {
	protected final AbstractType left;
	protected final AbstractType right;

	new(AbstractType left, AbstractType right, String source) {
		super(source);
		this.left = left;
		this.right = right;
		if(this.toString == "f_247.0 ≡ vec1d_args(anyVec(), f_242.0) → f_246.0") {
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
		val newL = f.apply(left);
		val newR = f.apply(right);
		if(left != newL || right != newR) {
			return new EqualityConstraint(newL, newR, '''EC:«BaseUtils.lineNumber» -> «errorMessage»''');
		} 
		else {
			return this;
		}
	}
	
	override getOperator() {
		return "≡"
	}
	
	override isAtomic() {
		return false;
	}
	
}