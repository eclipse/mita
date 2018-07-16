package org.eclipse.mita.base.typesystem.types

import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.naming.QualifiedName

@FinalFieldsConstructor
@EqualsHashCode
abstract class AbstractTypeVariable extends AbstractType {
}

@EqualsHashCode
class BoundTypeVariable extends AbstractTypeVariable {
	static Integer instanceCount = 0;
	
	protected final QualifiedName symbol;
	
	new(QualifiedName symbol) {
		super('''vb_«instanceCount++»''')
		this.symbol = symbol;
	}
	
	def getSymbol() {
		return symbol;
	}
}

@EqualsHashCode
class FreeTypeVariable extends AbstractTypeVariable {
	static Integer instanceCount = 0;
	
	new() {
		super('''vf_«instanceCount++»''')
	}
	
}
