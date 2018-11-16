package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

/**
 * Corresponds to instance relationship 𝜏 ⪯ σ as defined in
 * Generalizing Hindley-Milner Type Inference Algorithms
 * by Heeren et al., see https://pdfs.semanticscholar.org/8983/233b3dff2c5b94efb31235f62bddc22dc899.pdf
 */
@Accessors
@EqualsHashCode
class ExplicitInstanceConstraint extends AbstractTypeConstraint {
	protected final AbstractType instance;
	protected final AbstractType typeScheme;
	
	override toString() {
		instance + " ⩽ " + typeScheme
	}
	
	new(AbstractType instance, AbstractType typeScheme, ValidationIssue errorMessage) {
		super(errorMessage);
		this.instance = instance;
		this.typeScheme = typeScheme;
		if(this.toString == "f_116.0 ⩽ i32") {
			print("")
		}
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
	
	
	
	override map((AbstractType)=>AbstractType f) {
		return new ExplicitInstanceConstraint(instance.map(f), typeScheme.map(f), errorMessage);
	}
	
	override getOperator() {
		return "explicit instanceof"
	}
	
	override isAtomic() {
		return typeScheme instanceof TypeVariable
	}
	
}