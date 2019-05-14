/********************************************************************************
 * Copyright (c) 2018, 2019 Robert Bosch GmbH & TypeFox GmbH
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH & TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.infra.CachedBoolean
import org.eclipse.mita.base.typesystem.infra.NicerTypeVariableNamesForErrorMessages
import org.eclipse.mita.base.typesystem.infra.SubtypeChecker
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
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
		if(subType === null || superType === null) {
			throw new NullPointerException;
		}
	}
	
	override getErrorMessage() {
		val formatter = new NicerTypeVariableNamesForErrorMessages;
		val types = this.modifyNames(formatter) as SubtypeConstraint;
		return new ValidationIssue(_errorMessage, String.format(_errorMessage.message, types.subType, types.superType));
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
	
	private var CachedBoolean cachedIsAtomic = CachedBoolean.Uncached;
	
	override isAtomic(ConstraintSystem system) {
		if(cachedIsAtomic == CachedBoolean.Uncached) {
			cachedIsAtomic = CachedBoolean.from((subType.isAtomic && superType.isAtomic) || (system.canHaveSuperTypes(subType) || system.hasSubtypes(superType)) && !(typesAreCommon(subType, superType)));
		}
	 	return cachedIsAtomic.get();
	}
	
	dispatch def boolean typesAreCommon(AbstractType type, AbstractType type2) {
		return false
	}
	
	// for example t1 and t2 are sum type constructors. Then previously this was tv <= t2, now it's t1 <= t2. Then someone else already did what this constraint would have done. 
	dispatch def boolean typesAreCommon(TypeConstructorType type1, TypeConstructorType type2) {
		return type1.class == type2.class
	}
		
	dispatch def boolean hasSubtypes(ConstraintSystem system, AbstractType type) {
		val idxs = system.explicitSubtypeRelations.reverseMap.get(SubtypeChecker.getSuperTypeGraphHandle(type)) ?: #[];
		val explicitSuperTypes = idxs.flatMap[system.explicitSubtypeRelations.getPredecessors(it)];
		return !explicitSuperTypes.empty;
	}
	dispatch def boolean hasSubtypes(ConstraintSystem system, TypeConstructorType type) {
		return type.typeArguments.head.name == "optional" || system._hasSubtypes(type as AbstractType);
	}
	dispatch def boolean hasSubtypes(ConstraintSystem system, SumType type) {
		return !type.typeArguments.tail.empty || system._hasSubtypes(type as AbstractType);
	}
	
	def canHaveSuperTypes(ConstraintSystem system, AbstractType type) {
		val idxs = system.explicitSubtypeRelations.reverseMap.get(SubtypeChecker.getSuperTypeGraphHandle(type)) ?: #[];
		val explicitSuperTypes = idxs.flatMap[system.explicitSubtypeRelations.getSuccessors(it)];
		
		return !explicitSuperTypes.empty;
	}
	
	private def isAtomic(AbstractType t) {
		return t instanceof AbstractBaseType || t instanceof TypeVariable
	}
		
	override toGraphviz() {
		return '''"«subType»" -> "«superType»"; «subType.toGraphviz» «superType.toGraphviz»'''
	}
		
	override map((AbstractType)=>AbstractType f) {
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