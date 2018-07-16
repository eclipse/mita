package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@Accessors
@FinalFieldsConstructor
@EqualsHashCode
class Subtype extends AbstractTypeConstraint {
	protected final AbstractType subType;
	protected final AbstractType superType;
}