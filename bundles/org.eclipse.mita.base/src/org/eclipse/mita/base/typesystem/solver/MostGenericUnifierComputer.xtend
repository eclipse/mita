package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.TypeVariable

class MostGenericUnifierComputer {
	
	@Inject
	protected Provider<Substitution> substitutionProvider;
	
	def UnificationResult compute(AbstractType t1, AbstractType t2) {
		val t1IsFree = t1 instanceof TypeVariable;
		val t2IsFree = t2 instanceof TypeVariable;
		
		val result = substitutionProvider.get();
		if(t1IsFree && t2IsFree) {
			result.add(t1 as TypeVariable, t2);
		} else if(t1IsFree) {
			result.add(t1 as TypeVariable, t2);
		} else if(t2IsFree) {
			result.add(t2 as TypeVariable, t1);
		} else if(t1.class == t2.class) {
			val error = validateSubstitution(t1, t2);
			if(error !== null) {
				// mark substition as errornous
				return UnificationResult.failure(error);
			}
		} else {
			return UnificationResult.failure(#[t1, t2], '''Cannot unify «t1» and «t2»''');
		}
		
		// none is free - ask the defined types
		return UnificationResult.success(result);
	}
	
	protected dispatch def UnificationIssue validateSubstitution(AtomicType t1, AtomicType t2) {
		if(t1.name != t2.name) {
			return new UnificationIssue(#[t1, t2], '''Cannot unify «t1» and «t2»''');
		}
		
		// not an issue
		return null;
	}
	
	protected dispatch def UnificationIssue validateSubstitution(AbstractType t1, AbstractType t2) {
		return new UnificationIssue(#[t1, t2], '''Cannot unify «t1» and «t2»''');
	}

}