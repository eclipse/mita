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

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.types.Variance
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.infra.CachedBoolean
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.SimplificationResult
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AbstractType.NameModifier
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtext.naming.QualifiedName

@Accessors
@EqualsHashCode
class FunctionTypeClassConstraint extends TypeClassConstraint {
	
	val EObject functionCall;
	val EReference functionReference;
	val TypeVariable returnTypeTV;
	// covariant means that the result is giving something instead of taking
	// types are contravariant on the LHS of AssignmentExpressions 
	val Variance returnTypeVariance;
	
	@Inject
	val Provider<ConstraintSystem> constraintSystemProvider;
		
	new(ValidationIssue errorMessage, AbstractType typ, QualifiedName qn, EObject functionCall, EReference functionReference, TypeVariable returnTypeTV, Variance returnTypeVariance, Provider<ConstraintSystem> csp) {
		super(errorMessage, typ, qn);
		this.functionCall = functionCall;
		this.functionReference = functionReference;
		this.returnTypeTV = returnTypeTV;
		this.returnTypeVariance = returnTypeVariance;
		this.constraintSystemProvider = csp;
	}
	
	new(AbstractType typ, QualifiedName qn, EObject functionCall, EReference functionReference, TypeVariable returnTypeTV, Variance returnTypeVariance, ValidationIssue errorMessage) {
		this(errorMessage, typ, qn, functionCall, functionReference, returnTypeTV, returnTypeVariance, null);
	}
		
	override onResolve(ConstraintSystem cs, Substitution sub, EObject op, AbstractType at) {
		// now `at` is a concrete function type of operation `op`.
		// We introduce a constraint to make sure that this function's return is compatible with the expected type computed before.
		// (for example the explicit type of variable declarations)
		if(op !== null && functionReference !== null && !functionCall.eIsProxy) {
			BaseUtils.ignoreChange(functionCall, [functionCall.eSet(functionReference, op)]);
		}
		if(at instanceof FunctionType) {
			val newConstraint = switch(returnTypeVariance) {
				case COVARIANT: {
					// the returned type should be smaller than the expected type so it can be assigned
					new SubtypeConstraint(at.to, returnTypeTV, new ValidationIssue(_errorMessage, '''«_errorMessage.message»: Return type incompatible: %1$s is not subtype of %2$s'''));
				}
				case CONTRAVARIANT: {
					// if we are the target of an assignment we need to accept superclasses
					new SubtypeConstraint(returnTypeTV, at.to, new ValidationIssue(_errorMessage, '''«_errorMessage.message»: Return type incompatible: %1$s is not subtype of %2$s'''));
				}
				case INVARIANT: {
					new EqualityConstraint(returnTypeTV, at.to, new ValidationIssue(_errorMessage, '''«_errorMessage.message»: Return type incompatible: %1$s is not equal to %2$s'''));
				}
			}
			cs.addConstraint(newConstraint);
			return SimplificationResult.success(cs, sub)
		}
		else { 
			return SimplificationResult.failure(_errorMessage)
		}
	}
	
	override map((AbstractType)=>AbstractType f) {
		val newType = typ.map(f);
		if(newType !== typ) {
			return new FunctionTypeClassConstraint(_errorMessage, newType, instanceOfQN, functionCall, functionReference, returnTypeTV, returnTypeVariance, constraintSystemProvider);	
		}
		return this;
	}
	
	override modifyNames(NameModifier converter) {
		return new FunctionTypeClassConstraint(_errorMessage, typ.modifyNames(converter), instanceOfQN, functionCall, functionReference, returnTypeTV.modifyNames(converter) as TypeVariable, returnTypeVariance, constraintSystemProvider);
	}
	
	private var CachedBoolean cachedIsAtomic = CachedBoolean.Uncached;
	
	override isAtomic(ConstraintSystem system) {
		val typeClass = system.typeClasses.get(instanceOfQN);
		if(false || typeClass.mostSpecificGeneralization === null || typ.freeVars.empty) {	
			return !typ.freeVars.empty
		}
		if(cachedIsAtomic == CachedBoolean.Uncached) {
			cachedIsAtomic = CachedBoolean.from(!typ.isMoreSpecificThan(typeClass.mostSpecificGeneralization));
		}
	 	return cachedIsAtomic.get();
	}
	
	def boolean isMoreSpecificThan(AbstractType instance, AbstractType generalization) {
		// we only need the instantiated typescheme, but since we won't do anything with it other than looking at it (i.e. no constraints) we can just extract it
		val argType = if(generalization instanceof TypeScheme) {
			val funType = generalization.on;
			if(funType instanceof FunctionType) {
				funType.from;
			}
		}
		if(argType !== null) {
			val zipped = instance.quote.zip(argType.quote);
			
			// assure this has a more specific structure than the other, 
			// which is only the case if quoting like the other thing is more generic i.e. not the same.
			return (instance.quote != instance.quoteLike(argType.quote) 
				&& zipped.fold(false, [b, t1_t2 | 
					val t1 = t1_t2.key;
					val t2 = t1_t2.value;
					return b || (!(t1 instanceof TypeVariable) && (t2 instanceof TypeVariable))
				]))
		}
		else {
			// non type schemes are only type variables/should not happen
			return true;
		}		
	}
		
}