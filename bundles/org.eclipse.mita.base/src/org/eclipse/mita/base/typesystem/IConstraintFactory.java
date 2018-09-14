package org.eclipse.mita.base.typesystem;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem;

public interface IConstraintFactory {

	ConstraintSystem create(EObject context);
	
	void setIsLinking(boolean isLinking);
	
}
