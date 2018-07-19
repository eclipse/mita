package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.ArrayList
import java.util.List
import org.eclipse.mita.base.typesystem.constraints.Equality
import org.eclipse.mita.base.typesystem.constraints.Subtype

class ConstraintSolver {
	
	@Inject protected Provider<Substitution> substitutionProvider;
	
	@Inject protected MostGenericUnifierComputer mguComputer;
	
	protected List<UnificationIssue> issues;
	
	def Substitution solve(ConstraintSystem system) {
		issues = new ArrayList<UnificationIssue>();
		return system.doSolve();
	}
	
	public def getIssues() {
		return issues;
	}
	
	// equivalent to SOLVE(...) - call this function recursively from within the individual SOLVE dispatch functions
	protected def Substitution doSolve(ConstraintSystem system) {
		if(system.constraints.empty) {
			return Substitution.EMPTY;
		}
		
		val takeOne = system.takeOne();
		val result = takeOne.key.solve(takeOne.value);
		if(result.isValid) {
			return result.substition;
		} else {
			issues.add(result.issue);
			return Substitution.EMPTY;
		}
	}

	protected dispatch def UnificationResult solve(Equality constraint, ConstraintSystem constraints) {
		val unificationResult = mguComputer.compute(constraint.left, constraint.right);
		if(unificationResult.valid) {
			val mguSubstitution = unificationResult.substition;
			return UnificationResult.success(mguSubstitution.apply(mguSubstitution.apply(constraints).doSolve()));			
		} else {
			return unificationResult;
		}
	}
	
	protected dispatch def UnificationResult solve(Subtype constraint, ConstraintSystem constraints) {
		val instance = constraint.superType.instantiate();
		return UnificationResult.success(constraints.plus(new Equality(constraint.subType, instance.value)).doSolve());
	}
	
}
