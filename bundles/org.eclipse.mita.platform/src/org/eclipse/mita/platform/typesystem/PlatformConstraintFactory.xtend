package org.eclipse.mita.platform.typesystem

import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.platform.AbstractSystemResource

class PlatformConstraintFactory extends BaseConstraintFactory {
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, AbstractSystemResource res) {
		system.computeConstraintsForChildren(res);
		return null;
	}
}