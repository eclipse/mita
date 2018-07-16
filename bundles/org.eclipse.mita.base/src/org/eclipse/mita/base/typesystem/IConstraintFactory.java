package org.eclipse.mita.base.typesystem;

import org.eclipse.emf.ecore.EObject;

public interface IConstraintFactory {

	ConstraintSystem create(EObject context);
	
}
