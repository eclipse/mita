package org.eclipse.mita.base.typesystem.constraints

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.SimplificationResult
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.mita.base.util.BaseUtils

@FinalFieldsConstructor
@Accessors
@EqualsHashCode
class FunctionTypeClassConstraint extends TypeClassConstraint {
	
	val EObject functionCall;
	val EReference functionReference;
	val TypeVariable returnTypeTV;
	// covariant means that the result is giving something instead of taking
	// types are contravariant on the LHS of AssignmentExpressions 
	val boolean returnTypeIsCovariant;
	
	@Inject
	val Provider<ConstraintSystem> constraintSystemProvider;
		
	new(AbstractType typ, QualifiedName qn, EObject functionCall, EReference functionReference, TypeVariable returnTypeTV, Boolean returnTypeIsCovariant, ValidationIssue errorMessage) {
		this(errorMessage, typ, qn, functionCall, functionReference, returnTypeTV, returnTypeIsCovariant, null);
	}
		
	override onResolve(ConstraintSystem cs, Substitution sub, EObject op, AbstractType at) {
		if(functionReference !== null && !functionCall.eIsProxy) {
			BaseUtils.ignoreChange(functionCall, [functionCall.eSet(functionReference, op)]);
		}
		val nc = constraintSystemProvider.get(); 
		if(at instanceof FunctionType) {
			if(returnTypeIsCovariant) {
				// the returned type should be smaller than the expected type so it can be assigned
				nc.addConstraint(new SubtypeConstraint(at.to, returnTypeTV, new ValidationIssue(_errorMessage, '''«_errorMessage.message»: Return type incompatible: %1$s is not subtype of %2$s''')));
			}
			else {
				// if we are the target of an assignment we need to accept superclasses
				nc.addConstraint(new SubtypeConstraint(returnTypeTV, at.to, new ValidationIssue(_errorMessage, '''«_errorMessage.message»: Return type incompatible: %1$s is not subtype of %2$s''')));
			}
			return SimplificationResult.success(ConstraintSystem.combine(#[nc, cs]), sub)
		}
		else { 
			return SimplificationResult.failure(_errorMessage)
		}
	}
	
	override map((AbstractType)=>AbstractType f) {
		val newType = typ.map(f);
		if(newType !== typ) {
			return new FunctionTypeClassConstraint(_errorMessage, newType, instanceOfQN, functionCall, functionReference, returnTypeTV, returnTypeIsCovariant, constraintSystemProvider);	
		}
		return this;
	}
	
	override modifyNames(String suffix) {
		return new FunctionTypeClassConstraint(_errorMessage, typ.modifyNames(suffix), instanceOfQN, functionCall, functionReference, returnTypeTV.modifyNames(suffix) as TypeVariable, returnTypeIsCovariant, constraintSystemProvider);
	}
	
	override isAtomic() {
		return !typ.freeVars.empty
	}
	
		
}