package org.eclipse.mita.base.typesystem.types

import java.util.List
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@EqualsHashCode
class SumType extends AbstractType {
	private static Integer instanceCount = 0;
	
	protected final List<AbstractType> types;
	
	new(List<AbstractType> types) {
		super('''sum_«instanceCount++»''');
		this.types = types;
	}
	
	override toString() {
		"(" + types.join(" | ") + ")"
	}
	
	override replace(AbstractType from, AbstractType with) {
		return new SumType(this.types.map[ it.replace(from, with) ]);
	}
	
	override getFreeVars() {
		return types.filter(FreeTypeVariable);
	}
	
}