package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

/**
 * Corresponds to instance relationship 𝜏 ⪯ σ as defined in
 * Generalizing Hindley-Milner Type Inference Algorithms
 * by Heeren et al., see https://pdfs.semanticscholar.org/8983/233b3dff2c5b94efb31235f62bddc22dc899.pdf
 */
@Accessors
@FinalFieldsConstructor
@EqualsHashCode
class ExplicitInstanceConstraint extends AbstractTypeConstraint {
	protected final AbstractType instance;
	protected final AbstractType typeScheme;
	
	override toString() {
		instance + " ⩽ " + typeScheme
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return new ExplicitInstanceConstraint(instance.replace(from, with), typeScheme.replace(from, with));
	}
	
	override getActiveVars() {
		return instance.freeVars + typeScheme.freeVars;
	}
	
	override getOrigins() {
		return #[instance, typeScheme].map[ it.origin ];
	}
	
	override getTypes() {
		return #[instance, typeScheme];
	}
	
	override toGraphviz() {
		return "";
	}
	
	override replace(Substitution sub) {
		val inst = if(instance.freeVars.exists[sub.substitutions.containsKey(it)]) {
			instance.replace(sub);
		}
		else {
			instance;
		}
		val ts = if(typeScheme.freeVars.exists[sub.substitutions.containsKey(it)]) {
			typeScheme.replace(sub);
		}
		else {
			typeScheme;
		}
		
		return new ExplicitInstanceConstraint(instance.replace(sub), typeScheme.replace(sub));
	}
}