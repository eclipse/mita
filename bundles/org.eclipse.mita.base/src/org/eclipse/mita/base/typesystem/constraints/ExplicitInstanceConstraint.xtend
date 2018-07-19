package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

/**
 * Corresponds to subtype relationship 𝜏 ⪯ σ as defined in
 * Generalizing Hindley-Milner Type Inference Algorithms
 * by Heeren et al., see https://pdfs.semanticscholar.org/8983/233b3dff2c5b94efb31235f62bddc22dc899.pdf
 */
@Accessors
@FinalFieldsConstructor
@EqualsHashCode
class ExplicitInstanceConstraint extends AbstractTypeConstraint {
	protected final AbstractType subType;
	protected final AbstractType superType;
	
	override toString() {
		subType + " ⩽ " + superType
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return new ExplicitInstanceConstraint(subType.replace(from, with), superType.replace(from, with));
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
	
}