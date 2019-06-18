package org.eclipse.mita.program.inferrer

import com.google.inject.Inject
import org.eclipse.core.runtime.CoreException
import org.eclipse.core.runtime.Status
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.infra.NicerTypeVariableNamesForErrorMessages
import org.eclipse.mita.base.typesystem.solver.ConstraintSolution
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.IConstraintSolver
import org.eclipse.mita.base.typesystem.solver.MostGenericUnifierComputer
import org.eclipse.mita.base.typesystem.solver.SimplificationResult
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtext.diagnostics.Severity
import org.eclipse.mita.base.typesystem.constraints.MaxConstraint

import static extension org.eclipse.mita.base.util.BaseUtils.force;
import static extension org.eclipse.mita.base.util.BaseUtils.zip;
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint

// handles equality and max
class SizeConstraintSolver implements IConstraintSolver {
	@Inject
	MostGenericUnifierComputer mguComputer;
	@Inject
	ProgramSizeInferrer programSizeInferrer;
	
	override solve(ConstraintSolution inputSolution, EObject typeResolutionOrigin) {
		val issues = inputSolution.issues;
		val result = simplify(inputSolution.system, inputSolution.substitution, typeResolutionOrigin);
		if(!result.valid) {
			issues += result.issues;
		}
		return new ConstraintSolution(result.system, result.substitution, result.issues);
	}
	
	def SimplificationResult simplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin) {
		var resultSystem = system;
		var resultSub = substitution;
		var issues = newArrayList;
		var AbstractTypeConstraint lastConstraint = null;
		do {
			while(resultSystem.hasNonAtomicConstraints()) {
				val constraintOutdated = resultSystem.takeOneNonAtomic();
				val constraint = constraintOutdated.replace(resultSub);
				
				if(constraint.isAtomic(resultSystem)) {
					constraintOutdated.isAtomic(resultSystem);
					constraint.isAtomic(resultSystem);
					throw new CoreException(new Status(Status.ERROR, "org.eclipse.mita.base", "Assertion violated: Non atomic constraint became atomic!"));
				}
				
				val simplification = doSimplify(resultSystem, resultSub, typeResolutionOrigin, constraint);
				
				if(!simplification.valid) {
					issues += simplification.issues;
				}
				else {
					val returnedSub = simplification.substitution;
					val witnessesNotWeaklyUnifyable = returnedSub.substitutions.filter[tv_t | 
						tv_t.key != tv_t.value && tv_t.value.freeVars.exists[it == tv_t.key]
					].flatMap[#[it.key, it.value]].force;
					if(!witnessesNotWeaklyUnifyable.empty) {
						val niceRenamer = new NicerTypeVariableNamesForErrorMessages;
						issues += witnessesNotWeaklyUnifyable.map[new ValidationIssue(Severity.ERROR, "Types are recursive: " + witnessesNotWeaklyUnifyable.map[it.modifyNames(niceRenamer)].force.toString, it.origin, null, "")]; 
						witnessesNotWeaklyUnifyable.filter(TypeVariable).forEach[
							simplification.substitution.content.remove(it.idx);
						]
					}
					
					resultSystem = returnedSub.applyToGraph(simplification.system);
					resultSub = returnedSub.applyMutating(resultSub);
					
				}
				lastConstraint = constraint;
			}
			resultSystem = resultSub.applyToAtomics(resultSystem);	
			
		} while(resultSystem.hasNonAtomicConstraints());
		return new SimplificationResult(resultSub, issues, resultSystem);
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, ExplicitInstanceConstraint constraint) {
		val ts = constraint.typeScheme;
		if(ts instanceof TypeScheme) {
			val instance = ts.instantiate(system, constraint.instance.origin);
			val instanceType = instance.value
			val resultSystem = system.plus(
				new EqualityConstraint(constraint.instance, instanceType, constraint.errorMessage)
			)
			return SimplificationResult.success(resultSystem, Substitution.EMPTY);	
		}
		return SimplificationResult.failure(new ValidationIssue('''«ts» is not a generic type''', ts.origin));
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, MaxConstraint constraint) {
		programSizeInferrer.createConstraintsForMax(system, typeResolutionOrigin.eResource, constraint);
		return SimplificationResult.success(system, Substitution.EMPTY);
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, EqualityConstraint constraint) {
		val t1 = constraint.left;
		val t2 = constraint.right;
		if(t1 == t2) {
			return SimplificationResult.success(system, Substitution.EMPTY);
		}
		return system.doSimplify(substitution, typeResolutionOrigin, constraint, t1, t2);
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, EqualityConstraint constraint, TypeConstructorType t1, TypeConstructorType t2) {
		if(t1.class != t2.class || t1.typeArguments.size != t2.typeArguments.size) {
			return SimplificationResult.failure(constraint.errorMessage);
		}
		t1.typeArguments.zip(t2.typeArguments).forEach[
			system.addConstraint(new EqualityConstraint(it.key, it.value, constraint._errorMessage));
		]
		return SimplificationResult.success(system, Substitution.EMPTY);
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EObject typeResolutionOrigin, EqualityConstraint constraint, AbstractType t1, AbstractType t2) {
		// unify
		val mgu = mguComputer.compute(constraint._errorMessage, t1, t2);
		if(!mgu.valid) {
			return SimplificationResult.failure(mgu.issues);
		}
		
		return SimplificationResult.success(system, mgu.substitution);
	}
	
}