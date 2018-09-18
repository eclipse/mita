package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@Accessors
@EqualsHashCode
class EqualityConstraint extends AbstractTypeConstraint {
	protected final AbstractType left;
	protected final AbstractType right;
	protected val String source;

	new(AbstractType left, AbstractType right, String source) {
		this.left = left;
		this.right = right;
		this.source = source;
	}

	override toString() {
		left + " ≡ " + right
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return new EqualityConstraint(left.replace(from, with), right.replace(from, with), source);
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
	
	override replace(Substitution sub) {
		return new EqualityConstraint(left.replace(sub), right.replace(sub), source);
	}
	
	override replaceProxies((TypeVariableProxy) => AbstractType resolve) {
		return new EqualityConstraint(left.replaceProxies(resolve), right.replaceProxies(resolve), source);
	}
	
}