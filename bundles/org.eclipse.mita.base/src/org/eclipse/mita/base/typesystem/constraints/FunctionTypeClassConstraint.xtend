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
import org.eclipse.mita.base.typesystem.types.Variance

@FinalFieldsConstructor
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
		if(this.toString.startsWith("read_args(f_84<xint8>) :: read")) {
			print("");
		}
	}
	
	new(AbstractType typ, QualifiedName qn, EObject functionCall, EReference functionReference, TypeVariable returnTypeTV, Variance returnTypeVariance, ValidationIssue errorMessage) {
		this(errorMessage, typ, qn, functionCall, functionReference, returnTypeTV, returnTypeVariance, null);
	}
		
	override onResolve(ConstraintSystem cs, Substitution sub, EObject op, AbstractType at) {
		if(functionReference !== null && !functionCall.eIsProxy) {
			BaseUtils.ignoreChange(functionCall, [functionCall.eSet(functionReference, op)]);
		}
		val nc = constraintSystemProvider.get(); 
		if(at instanceof FunctionType) {
			val newConstraint = switch(returnTypeVariance) {
				case Covariant: {
					if(this.toString.startsWith("read_args(modality<int32>) :: read")) {
						print("");
					}
					// the returned type should be smaller than the expected type so it can be assigned
					new SubtypeConstraint(at.to, returnTypeTV, new ValidationIssue(_errorMessage, '''«_errorMessage.message»: Return type incompatible: %1$s is not subtype of %2$s'''));
				}
				case Contravariant: {
					// if we are the target of an assignment we need to accept superclasses
					new SubtypeConstraint(returnTypeTV, at.to, new ValidationIssue(_errorMessage, '''«_errorMessage.message»: Return type incompatible: %1$s is not subtype of %2$s'''));
				}
				case Invariant: {
					new EqualityConstraint(returnTypeTV, at.to, new ValidationIssue(_errorMessage, '''«_errorMessage.message»: Return type incompatible: %1$s is not equal to %2$s'''));
				}
				
			}
			nc.addConstraint(newConstraint);
			return SimplificationResult.success(ConstraintSystem.combine(#[nc, cs]), sub)
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
	
	override modifyNames(String suffix) {
		return new FunctionTypeClassConstraint(_errorMessage, typ.modifyNames(suffix), instanceOfQN, functionCall, functionReference, returnTypeTV.modifyNames(suffix) as TypeVariable, returnTypeVariance, constraintSystemProvider);
	}
	
	override isAtomic() {
		return !typ.freeVars.empty
	}
	
		
}