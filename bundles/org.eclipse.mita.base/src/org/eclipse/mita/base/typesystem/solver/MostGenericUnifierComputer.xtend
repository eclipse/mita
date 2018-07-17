package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.FreeTypeVariable

class MostGenericUnifierComputer {
	
	@Inject
	protected Provider<Substitution> substitutionProvider;
	
	def Substitution compute(AbstractType t1, AbstractType t2) {
		val t1IsFree = t1 instanceof FreeTypeVariable;
		val t2IsFree = t2 instanceof FreeTypeVariable;
		
		val result = substitutionProvider.get();
		if(t1IsFree && t2IsFree) {
			result.add(t1 as FreeTypeVariable, t2);
		} else if(t1IsFree) {
			result.add(t1 as FreeTypeVariable, t2);
		} else if(t2IsFree) {
			result.add(t2 as FreeTypeVariable, t1);
		} else if(t1.class == t2.class) {
			
		}
			// none is free - ask the defined types
		return result;
	}

}