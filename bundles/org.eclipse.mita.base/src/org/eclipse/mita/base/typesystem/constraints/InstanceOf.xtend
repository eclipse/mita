package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor 
@EqualsHashCode
class InstanceOf extends AbstractTypeConstraint {
	protected final AbstractType isInstance;
	protected final AbstractType typeScheme;
	
	override replace(TypeVariable from, AbstractType with) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override getActiveVars() {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
}
