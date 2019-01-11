package org.eclipse.mita.base.typesystem.constraints

import com.google.common.base.Optional
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

/**
 * Corresponds to subtype relationship sub <: sup as defined in
 * Extending Hindley-Milner Type Inference with Coercive Structural Subtyping
 * by Traytel et al., see https://www21.in.tum.de/~nipkow/pubs/aplas11.pdf
 */
@Accessors
@EqualsHashCode
class SubtypeConstraint extends AbstractTypeConstraint {
	protected final AbstractType subType;
	protected final AbstractType superType;
	
	new(AbstractType sub, AbstractType top, ValidationIssue errorMessage) {
		super(errorMessage);
		
		subType = sub;
		superType = top;
		if(this.toString == ("int32 ⩽ f_145.0")) {
			print("")
		}
	}
	
	override getErrorMessage() {
		return new ValidationIssue(_errorMessage, String.format(_errorMessage.message, subType, superType));
	}
	
	override toString() {
		subType + " ⩽ " + superType
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
	
	private var Optional<Boolean> cachedIsAtomic = Optional.absent;
	
	override isAtomic(ConstraintSystem system) {
		if(!cachedIsAtomic.present) {
			cachedIsAtomic = Optional.of((subType.isAtomic && superType.isAtomic) || system.canHaveSuperTypes(subType) || system.hasSubtypes(superType));
		}
	 	return cachedIsAtomic.get();
	}
		
	dispatch def boolean hasSubtypes(ConstraintSystem system, AbstractType type) {
		val idxs = system.explicitSubtypeRelations.reverseMap.get(type) ?: #[];
		val explicitSuperTypes = idxs.flatMap[system.explicitSubtypeRelations.getPredecessors(it)];
		return !explicitSuperTypes.empty;
	}
	dispatch def boolean hasSubtypes(ConstraintSystem system, TypeConstructorType type) {
		return type.type.name == "optional" || system._hasSubtypes(type as AbstractType);
	}
	dispatch def boolean hasSubtypes(ConstraintSystem system, SumType type) {
		return !type.typeArguments.empty || system._hasSubtypes(type as AbstractType);
	}
	
	def canHaveSuperTypes(ConstraintSystem system, AbstractType type) {
		
		val idxs = system.explicitSubtypeRelations.reverseMap.get(type) ?: #[];
		val explicitSuperTypes = idxs.flatMap[system.explicitSubtypeRelations.getSuccessors(it)];
		
		return explicitSuperTypes.empty;
	}
	
	private def isAtomic(AbstractType t) {
		return t instanceof AbstractBaseType || t instanceof TypeVariable
	}
	
	private def isCompositeButShouldNotBeResolved(AbstractType t) {
		(t instanceof ProdType)
	}
	
	override toGraphviz() {
		return '''"«subType»" -> "«superType»"; «subType.toGraphviz» «superType.toGraphviz»'''
	}
		
	override map((AbstractType)=>AbstractType f) {
		if(this.toString == ("int32 ⩽ f_145.0")) {
			print("")
		}
		val newL = subType.map(f);
		val newR = superType.map(f);
		if(subType !== newL || superType !== newR) {
			return new SubtypeConstraint(newL, newR, _errorMessage);
		}
		return this;
	}
	
	override getOperator() {
		return "⩽"
	}
	
}