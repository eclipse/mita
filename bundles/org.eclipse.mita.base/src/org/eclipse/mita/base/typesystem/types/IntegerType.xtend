package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject

class IntegerType extends AbstractType {
	protected final int byteLength;
	protected final boolean signed;
	
	new(EObject origin, int byteLength, boolean signed) {
		super(origin, '''«if(signed) 'i' else 'u'»«byteLength * 8»''');
		this.byteLength = byteLength;
		this.signed = signed;
	}
	
	override replace(AbstractType from, AbstractType with) {
		return this;
	}
	
	override getFreeVars() {
		return #[];
	}
	
	override instantiate() {
		return this;
	}
	
}