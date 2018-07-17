package org.eclipse.mita.base.typesystem.types

import java.util.ArrayList
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@EqualsHashCode
class SumType extends AbstractType {
	private static Integer instanceCount = 0;
	
	protected final List<AbstractType> types;
	
	new(EObject origin, List<AbstractType> types) {
		super(origin, '''sum_«instanceCount++»''');
		this.types = types;
	}
	
	override toString() {
		"(" + types.join(" | ") + ")"
	}
	
	override replace(AbstractType from, AbstractType with) {
		return new SumType(origin, this.types.map[ it.replace(from, with) ]);
	}
	
	override getFreeVars() {
		return types.filter(TypeVariable);
	}
	
	override instantiate() {
		val ntypes = new ArrayList<AbstractType>();
		for(t : types) {
			ntypes.add(
				if(t instanceof TypeVariable) {
					new TypeVariable(t.origin);
				} else {
					t
				}
			);
		}
		
		return new SumType(origin, ntypes);
	}
	
}