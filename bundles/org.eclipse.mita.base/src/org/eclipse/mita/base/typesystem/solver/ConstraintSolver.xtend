package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.mita.base.typesystem.constraints.Equality
import org.eclipse.mita.base.typesystem.constraints.Subtype

class ConstraintSolver {
	
	@Inject protected Provider<Substitution> substitutionProvider;
	
	def Substitution solve(ConstraintSystem system) {
		if(system.constraints.empty) {
			return Substitution.EMPTY;
		}
		
		val takeOne = system.takeOne();
		return takeOne.key.solve(takeOne.value);
	}

	protected dispatch def Substitution solve(Equality constraint, ConstraintSystem constraints) {
		val Substitution mguSubstitution = null;
		return mguSubstitution.apply(mguSubstitution.apply(constraints).solve());
	}
	
	protected dispatch def Substitution solve(Subtype constraint, ConstraintSystem constraints) {
		val instance = constraint.superType.instantiate();
		return constraints.plus(new Equality(constraint.subType, instance)).solve();
	}
	
}
