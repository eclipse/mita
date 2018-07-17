package org.eclipse.mita.base.typesystem.types

import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.naming.QualifiedName

@FinalFieldsConstructor
@EqualsHashCode
abstract class AbstractTypeVariable extends AbstractType {
	
	override AbstractType replace(AbstractType from, AbstractType with) {
		return if(from == this) with else this;
	}
	
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
	
	override toString() {
		symbol.lastSegment
	}
	
	override getFreeVars() {
		return #[];
	}
	
}

@EqualsHashCode
class FreeTypeVariable extends AbstractTypeVariable {
	static Integer instanceCount = 0;
	
	new() {
		super('''vf_«instanceCount++»''')
	}
	
	override toString() {
		name.replaceFirst("vf_", "t")
	}
	
	override getFreeVars() {
		return #[this];
	}
	
}
