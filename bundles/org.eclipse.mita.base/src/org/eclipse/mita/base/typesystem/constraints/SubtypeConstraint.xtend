package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.mita.base.typesystem.types.AtomicType

/**
 * Corresponds to subtype relationship sub <: sup as defined in
 * Extending Hindley-Milner Type Inference with Coercive Structural Subtyping
 * by Traytel et al., see https://www21.in.tum.de/~nipkow/pubs/aplas11.pdf
 */
@Accessors
@FinalFieldsConstructor
@EqualsHashCode
class SubtypeConstraint extends AbstractTypeConstraint {
	protected final AbstractType subType;
	protected final AbstractType superType;
	
	override toString() {
		subType + " ⩽ " + superType
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return new SubtypeConstraint(subType.replace(from, with), superType.replace(from, with));
	}
	
	override getActiveVars() {
		return subType.freeVars + superType.freeVars;
	}
	
	override getOrigins() {
		return #[subType, superType].map[ it.origin ];
	}
	
	override getTypes() {
		return #[subType, superType];
	}
	
	def isAtomic() {
		return (subType instanceof TypeVariable && superType instanceof TypeVariable)
			|| (subType instanceof TypeVariable && superType instanceof AtomicType)
			|| (subType instanceof AtomicType && superType instanceof TypeVariable);
	}
	
}