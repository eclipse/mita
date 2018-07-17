package org.eclipse.mita.base.typesystem;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem;
import org.eclipse.mita.base.typesystem.solver.SymbolTable;

public interface IConstraintFactory {

	ConstraintSystem create(SymbolTable symbols, EObject context);
	
}
