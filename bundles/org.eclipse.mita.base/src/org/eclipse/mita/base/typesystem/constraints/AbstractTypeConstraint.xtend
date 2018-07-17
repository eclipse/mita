package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AbstractTypeVariable
import org.eclipse.mita.base.typesystem.types.FreeTypeVariable

abstract class AbstractTypeConstraint {
	
	abstract def AbstractTypeConstraint replace(AbstractTypeVariable from, AbstractType with);
	
	abstract def Iterable<FreeTypeVariable> getActiveVars();
	
}
