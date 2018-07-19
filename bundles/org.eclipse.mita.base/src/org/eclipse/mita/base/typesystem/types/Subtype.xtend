package org.eclipse.mita.base.typesystem.types

import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.emf.ecore.EObject

class Subtype extends AbstractType {
	protected final AbstractType upperBound
	
	new(AbstractType upperBound) {
		super(upperBound.origin, '''st_«upperBound.name»''');
		this.upperBound = upperBound;
	}
	
	new(EObject origin, AbstractType upperBound) {
		super(origin, '''st_«upperBound.name»''');
		this.upperBound = upperBound;
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return new Subtype(origin, upperBound.replace(from, with));
	}
	
	override getFreeVars() {
		return #[upperBound].filter(TypeVariable);
	}
	
}