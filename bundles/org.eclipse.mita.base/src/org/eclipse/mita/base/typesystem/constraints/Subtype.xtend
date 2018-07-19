package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@Accessors
@FinalFieldsConstructor
@EqualsHashCode
class Subtype extends AbstractTypeConstraint {
	protected final AbstractType subType;
	protected final AbstractType superType;
	
	override toString() {
		subType + " ⩽ " + superType
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return new Subtype(subType.replace(from, with), superType.replace(from, with));
	}
	
	override getActiveVars() {
		return subType.freeVars + superType.freeVars;
	}
	
	override getOrigins() {
		return #[subType, superType].map[ it.origin ];
	}
	
}