package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@FinalFieldsConstructor 
@EqualsHashCode
class Equality extends AbstractTypeConstraint {
	protected final AbstractType left;
	protected final AbstractType right;

	override toString() {
		left + " ≡ " + right
	}
	
}