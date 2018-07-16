package org.eclipse.mita.base.typesystem.types

import org.eclipse.xtend.lib.annotations.EqualsHashCode

@EqualsHashCode
class FunctionType extends AbstractType {
	private static Integer instanceCount = 0;
	
	protected final AbstractType from;
	protected final AbstractType to;
	
	new(AbstractType from, AbstractType to) {
		super('''fun_«instanceCount++»''');
		this.from = from;
		this.to = to;
	}
	
}