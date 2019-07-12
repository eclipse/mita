package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.LiteralTypeExpression
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip

/**
 * SumConstraint expresses that 
 * target = max(t1, t2, t3, t4, ...)
 * the biggest type of t1...tn
 * 
 * The difference to EqualityConstraint (target = NumericMaxType([t1, t2, ...]) is that MaxConstraint resolves if t1... are solved far enough.
 */
@Accessors
class MaxConstraint extends AbstractTypeConstraint {
	val TypeVariable target;
	val Iterable<AbstractType> arguments;
	
	// arguments should be mostly of the same type. if you mix literal and normal types the latter ones will probably be ignored.
	new(TypeVariable target, Iterable<AbstractType> arguments, ValidationIssue _errorMessage) {
		super(_errorMessage)
		this.target = target;
		this.arguments = arguments.force;
		if(this.arguments.empty) {
			throw new IllegalArgumentException;
		}
		if(_errorMessage === null) {
			throw new NullPointerException;
		}
	}
	
	override map((AbstractType)=>AbstractType f) {
		val newArgs = arguments.map[it.map(f)].force;
		if(arguments.zip(newArgs).exists[it.key !== it.value]) {
			return new MaxConstraint(target, newArgs, _errorMessage);
		}
		return this;
	}
		
	override getTypes() {
		return arguments;
	}
	
	override getOperator() {
		return " = max "
	}
	
	override toString() {
		return target + operator + arguments
	}
	
	override toGraphviz() {
		return ""
	}
	
	// max can be simplified if:
	// - any one is a typeConstructorType, all need to be one, so we can recurse further (except for LiteralTypeExpressions, which are sort of like atomic types, i.e. '1 + '2)
	// - else, if any one is an atomic type, we won't recurse, so we can directly assign the max type, and its gonna replace contents later on.
	override isAtomic(ConstraintSystem system) {
		if(arguments.exists[it instanceof TypeConstructorType && !(it instanceof LiteralTypeExpression)]) {
			return !arguments.forall[it instanceof TypeConstructorType];
		}
		else {
			return !(arguments.forall[it instanceof AbstractBaseType] || arguments.exists[it instanceof LiteralTypeExpression])
		}
	}
		
	override hasProxy() {
		return arguments.exists[it.hasProxy];
	}
	
}