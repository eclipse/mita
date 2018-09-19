package org.eclipse.mita.base.typesystem.solver;

import org.eclipse.emf.ecore.EObject;

public interface IConstraintSolver {

	public ConstraintSolution solve(ConstraintSystem system, EObject typeResolutionOrigin);
	
}