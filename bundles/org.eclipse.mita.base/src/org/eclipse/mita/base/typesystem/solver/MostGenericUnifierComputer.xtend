package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.Signedness

/* Interesting papers:
 *  Generalizing Hindley-Milner Type Inference Algorithms: https://pdfs.semanticscholar.org/8983/233b3dff2c5b94efb31235f62bddc22dc899.pdf
 *  Extending Hindley-Milner Type Inference wit Coercive Structural Subtyping: https://www21.in.tum.de/~nipkow/pubs/aplas11.pdf
 * 			(relevant for int, structs)
 * 
 *  Coercions in a polymorphic type system
 *  Luo, see https://www.cs.rhul.ac.uk/home/zhaohui/WIT07.pdf
 *     (introduces coercions as axioms or derived. Can also be used to solve function overloading)
 */
class MostGenericUnifierComputer {
	
	@Inject
	protected Provider<Substitution> substitutionProvider;
	
	def UnificationResult compute(AbstractType t1, AbstractType t2) {
		val t1IsFree = t1 instanceof TypeVariable;
		val t2IsFree = t2 instanceof TypeVariable;
		
		val result = substitutionProvider.get();
		if(t1IsFree) {
			result.add(t1 as TypeVariable, t2);
		} else if(t2IsFree) {
			result.add(t2 as TypeVariable, t1);
		} else if(t1.class == t2.class) {
			val error = result.unify(t1, t2);
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
	
	protected dispatch def UnificationIssue unify(Substitution substitution, IntegerType t1, IntegerType t2) {
		return t1.isSubtypeOf(t2) ?: t2.isSubtypeOf(t1);		
	}
	
	protected dispatch def UnificationIssue unify(Substitution substitution, ProdType t1, ProdType t2) {
		val issues = t1.types.indexed.map[i_type |
			substitution.unify(i_type.value, t2.types.get(i_type.key))
		].filterNull
		if(issues.size === 1) {
			return issues.head;	
		}
		else if(!issues.empty) {
			return new UnificationIssue(issues, 
			'''
			multiple issues:
				«FOR issue: issues»
				«issue»
				«ENDFOR»
			'''
			);
		}
		return null;
	}
	
	protected dispatch def UnificationIssue unify(Substitution substitution, SumType t1, SumType t2) {
		val issues = t1.types.indexed.map[i_type |
			substitution.unify(i_type.value, t2.types.get(i_type.key))
		].filterNull
		if(issues.size === 1) {
			return issues.head;	
		}
		else if(!issues.empty) {
			return new UnificationIssue(issues, 
			'''
			multiple issues:
				«FOR issue: issues»
				«issue»
				«ENDFOR»
			'''
			);
		}
		return null;
	}
	
	protected dispatch def UnificationIssue unify(Substitution substitution, FunctionType t1, FunctionType t2) {
		val issues = #[
			substitution.unify(t1.from, t2.from),
			substitution.unify(t1.to, t2.to)
		].filterNull;
		
		if(issues.size === 1) {
			return issues.head;	
		}
		else if(!issues.empty) {
			return new UnificationIssue(issues, 
			'''
			multiple issues:
				«FOR issue: issues»
				«issue»
				«ENDFOR»
			'''
			);
		}
		return null;
	}
	
	protected dispatch def UnificationIssue unify(Substitution substitution, TypeVariable t1, AbstractType t2) {
		return substitution.unify(t2, t1);
	}
	protected dispatch def UnificationIssue unify(Substitution substitution, AbstractType t1, TypeVariable t2) {
		substitution.add(t2, t1);
		return null;
	}
	
	protected dispatch def UnificationIssue unify(Substitution substitution, AtomicType t1, AtomicType t2) {
		if(t1.name != t2.name) {
			return new UnificationIssue(#[t1, t2], '''Cannot unify «t1» and «t2»''');
		}
		
		// not an issue
		return null;
	}
	
	protected dispatch def UnificationIssue unify(Substitution substitution, TypeConstructorType t1, TypeConstructorType t2) {
		if(t1.name != t2.name) {
			return new UnificationIssue(#[t1, t2], '''Cannot unify «t1» and «t2»''');
		}
		
		if(t1.freeVars.size !== t2.freeVars.size) {
			return new UnificationIssue(#[t1, t2], '''Cannot unify with different number of type arguments: «t1» and «t2»''')
		}
		
		if(!t1.freeVars.empty) {
			// order of replacing free vars doesn't matter
			t1.freeVars.indexed.forEach[i_var | 
				substitution.add(i_var.value, t2.freeVars.get(i_var.key))	
			]
		}
		
		// not an issue
		return null;
	}
	
	protected dispatch def UnificationIssue unify(Substitution substitution, AbstractType t1, AbstractType t2) {
		return new UnificationIssue(#[t1, t2], '''Cannot unify «t1» and «t2»''');
	}
	
	public dispatch def UnificationIssue isSubtypeOf(IntegerType sub, IntegerType sup) {
		if(sub.signedness != sup.signedness && sub.signedness == Signedness.Signed && sup.signedness == Signedness.Unsigned && !(sub.signedness == Signedness.DontCare || sup.signedness == Signedness.DontCare)) {
			return new UnificationIssue(#[sub, sup], '''Incompatible signedness between «sup.name» and «sub.name»''');
		}
		
		if((sub.signedness == Signedness.Unsigned && sup.signedness != Signedness.Unsigned && sub.widthInBytes + 1 > sup.widthInBytes)
		|| (sub.widthInBytes > sup.widthInBytes)
		) {
			return new UnificationIssue(#[sub, sup], '''«sup.name» is too small for «sub.name»''');
		}
		
		return null;
	}
		
	public dispatch def UnificationIssue isSubtypeOf(AbstractType sub, AbstractType sup) {
		return new UnificationIssue(#[sub, sup], '''«sub.name» is not a subtype of «sup.name»''')
	}

}