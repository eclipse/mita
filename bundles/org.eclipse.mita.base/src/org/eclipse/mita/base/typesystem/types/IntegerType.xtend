package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@Accessors
@EqualsHashCode
class IntegerType extends AbstractType {
	protected final int widthInBytes;
	protected final boolean signed;
	
	new(EObject origin, int widthInBytes, boolean signed) {
		super(origin, '''«if(signed) 'i' else 'u'»«widthInBytes * 8»''');
		this.widthInBytes = widthInBytes;
		this.signed = signed;
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return this;
	}
	
	override getFreeVars() {
		return #[];
	}
}