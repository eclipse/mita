package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor
@Accessors
@EqualsHashCode
class InterpolatedStringExpressionConstraint extends AbstractTypeConstraint {
	/*
	 * This is a very specialized constraint that types dynamic sizes of IPS.
	 * Its the most elegant way I've found to make sizes depend on the type of type thats not overly complex.
	 * A bit nicer would be to create functions for each type:
	 * generated fn __STR__(x: uint32): string<10>
	 * generated fn <T> __STR__(x: string<T>): string<T>
	 * ...
	 * but this requires a more complex IPS constraint generation in the first typing pass.
	 * It would enable custom string interpolations and will probably come in the future, 
	 * at which point this class will be obsolete.
	 */
	val Expression origin;
	val TypeVariable target;
	val AbstractType matchType;
	
	override map((AbstractType)=>AbstractType f) {
		val newMatchType = matchType.map(f);
		if(newMatchType !== matchType) {
			return new InterpolatedStringExpressionConstraint(_errorMessage, origin, target, newMatchType);
		}
		return this;
	}
	
	override getTypes() {
		return #[target, matchType]
	}
	
	override getOperator() {
		return "ips"
	}
	
	override toGraphviz() {
		return "";
	}
	
	override isAtomic(ConstraintSystem system) {
		return matchType instanceof TypeVariable;
	}
	
	override hasProxy() {
		return matchType.hasProxy
	}
	
}