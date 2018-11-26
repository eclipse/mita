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

@FinalFieldsConstructor
@Accessors
@EqualsHashCode
class FunctionTypeClassConstraint extends TypeClassConstraint {
	
	val EObject functionCall;
	val EReference functionReference;
	val TypeVariable returnTypeTV;
	
	@Inject
	val Provider<ConstraintSystem> constraintSystemProvider;
		
	new(AbstractType typ, QualifiedName qn, EObject functionCall, EReference functionReference, TypeVariable returnTypeTV, ValidationIssue errorMessage) {
		this(errorMessage, typ, qn, functionCall, functionReference, returnTypeTV, null);
	}
		
	override onResolve(ConstraintSystem cs, Substitution sub, EObject op, AbstractType at) {
		if(functionReference !== null) {
			//functionCall.eSet(functionReference, op);
		}
		val nc = constraintSystemProvider.get(); 
		if(at instanceof FunctionType) {
			// the returned type should be smaller than the expected type so it can be assigned
			nc.addConstraint(new SubtypeConstraint(at.to, returnTypeTV, new ValidationIssue(_errorMessage, '''«_errorMessage.message»: Return type incompatible''')));
			return SimplificationResult.success(ConstraintSystem.combine(#[nc, cs]), sub)
		}
		else { 
			return SimplificationResult.failure(_errorMessage)
		}
	}
	
	override map((AbstractType)=>AbstractType f) {
		val newType = typ.map(f);
		if(newType !== typ) {
			return new FunctionTypeClassConstraint(_errorMessage, newType, instanceOfQN, functionCall, functionReference, returnTypeTV, constraintSystemProvider);	
		}
		return this;
	}
	
	override modifyNames(String suffix) {
		return new FunctionTypeClassConstraint(_errorMessage, typ.modifyNames(suffix), instanceOfQN, functionCall, functionReference, returnTypeTV.modifyNames(suffix) as TypeVariable, constraintSystemProvider);
	}
	
	override isAtomic() {
		return !typ.freeVars.empty
	}
	
		
}