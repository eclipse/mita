package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.mita.base.typesystem.solver.Substitution

@Accessors
@EqualsHashCode
class IntegerType extends NumericType {
	protected final Signedness signedness;
	
	new(EObject origin, int widthInBytes, Signedness signedness) {
		super(origin, '''«signedness.prefix»«widthInBytes * 8»''', widthInBytes);
		this.signedness = signedness;
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return this;
	}
	
	override getFreeVars() {
		return #[];
	}
	
	protected def static String prefix(Signedness signedness) {
		if(signedness == Signedness.Signed) {
			return 'int';
		} else if(signedness == Signedness.Unsigned) {
			return 'uint';
		} else {
			return 'xint';
		}
	}
	
	override replace(Substitution sub) {
		return this;
	}
	
}

enum Signedness {
	Signed,
	Unsigned,
	DontCare
}
