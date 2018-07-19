package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.ArrayList
import java.util.List
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint

class ConstraintSolver {
	
	@Inject protected Provider<Substitution> substitutionProvider;
	
	@Inject protected MostGenericUnifierComputer mguComputer;
	
	protected List<UnificationIssue> issues;
	
	def ConstraintSolution solve(ConstraintSystem system) {
		issues = new ArrayList<UnificationIssue>();
		val solution = system.doSolve();
		return new ConstraintSolution(system, solution, issues);
	}
	
	// equivalent to SOLVE(...) - call this function recursively from within the individual SOLVE dispatch functions
	// this function skips subtype constraints so that we can later solve them globally
	protected def Substitution doSolve(ConstraintSystem system) {
		if(system.constraints.empty) {
			return Substitution.EMPTY;
		}
		
		var takeOne = system.takeOne();
		val result = takeOne.key.solve(takeOne.value);
		if(result.isValid) {
			return result.substition;
		} else {
			issues.add(result.issue);
			return Substitution.EMPTY;
		}
	}

	protected dispatch def UnificationResult solve(EqualityConstraint constraint, ConstraintSystem constraints) {
		val unificationResult = mguComputer.compute(constraint.left, constraint.right);
		if(unificationResult.valid) {
			val mguSubstitution = unificationResult.substition;
			return UnificationResult.success(mguSubstitution.apply(mguSubstitution.apply(constraints).doSolve()));			
		} else {
			return unificationResult;
		}
	}
	
	protected dispatch def UnificationResult solve(ExplicitInstanceConstraint constraint, ConstraintSystem constraints) {
		val instance = constraint.superType.instantiate();
		return UnificationResult.success(constraints.plus(new EqualityConstraint(constraint.subType, instance.value)).doSolve());
	}
	
}
