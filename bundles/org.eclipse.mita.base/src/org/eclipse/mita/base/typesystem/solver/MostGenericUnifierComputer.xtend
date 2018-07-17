package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable

class MostGenericUnifierComputer {
	
	@Inject
	protected Provider<Substitution> substitutionProvider;
	
	def Substitution compute(AbstractType t1, AbstractType t2) {
		val t1IsFree = t1 instanceof TypeVariable;
		val t2IsFree = t2 instanceof TypeVariable;
		
		val result = substitutionProvider.get();
		if(t1IsFree && t2IsFree) {
			result.add(t1 as TypeVariable, t2);
		} else if(t1IsFree) {
			result.add(t1 as TypeVariable, t2);
		} else if(t2IsFree) {
			result.add(t2 as TypeVariable, t1);
		} else {
			println('''Unable to unify «t1» and «t2»''');
		}
			// none is free - ask the defined types
		return result;
	}
	
	

}