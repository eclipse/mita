/********************************************************************************
 * Copyright (c) 2018, 2019 Robert Bosch GmbH & TypeFox GmbH
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH & TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable

import static extension org.eclipse.mita.base.util.BaseUtils.*

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
	
	@Inject
	protected StdlibTypeRegistry typeRegistry;
	
	def UnificationResult compute(Iterable<Pair<AbstractType, AbstractType>> typeEqualities) {
		val result = UnificationResult.success(substitutionProvider.get());

		return typeEqualities.fold(result, [u1, t1_t2 | 
			if(!u1.valid) {
				return u1;
			} 
			val t1 = t1_t2.key;
			val t2 = t1_t2.value;
			val u2 = compute(null, t1, t2);
			return combine(u1, u2);
		])
	}
	
	protected def UnificationResult combine(UnificationResult u1, UnificationResult u2) {
		if(!u1.valid && !u2.valid) {
			return UnificationResult.failure(u1.issues + u2.issues);
		}
		else if(!u1.valid) {
			return u1;
		}
		else if(!u2.valid) {
			return u2;
		}
		val s1 = u1.substitution;
		val s2 = u2.substitution;
		
		return combine(s1, s2); 
	}
	
	protected def UnificationResult combine(Substitution s1, Substitution s2) {
		val conflictsS1 = s1.content.filter[p1, __ | s2.content.containsKey(p1)].entrySet;
		val conflictsS2 = s2.content.filter[p1, __ | s1.content.containsKey(p1)].entrySet;
		// try to unify conflicts
		val unificationResult = conflictsS1.reject[conflictsS2.contains(it)].fold(UnificationResult.success(substitutionProvider.get()), [ur, tv_t |
			if(!ur.valid) {
				// short-circuit failure
				return ur;
			}
			val tv = tv_t.key;
			val t1 = tv_t.value;
			val t2 = s2.content.get(tv);
			val unification = compute(null, t1, t2);
			if(unification.valid) {
				if(unification.substitution.content.containsKey(tv)) {
					ur.substitution.add(tv, unification.substitution.content.get(tv));
				}
				// else nothing to do because types just agree
				// finally return the built unification
				return ur;
			}
			else {
				return unification;
			}
		])
		if(!unificationResult.valid) {
			return unificationResult
		}
		return UnificationResult.success(s2.apply(s1).apply(unificationResult.substitution));
	}
	
	def UnificationResult compute(ValidationIssue issue, AbstractType t1, AbstractType t2) {
		val t1IsFree = t1 instanceof TypeVariable;
		val t2IsFree = t2 instanceof TypeVariable;
		
		val result = substitutionProvider.get();
		if(t1IsFree) {
			result.add(t1 as TypeVariable, t2);
			return UnificationResult.success(result);
		} else if(t2IsFree) {
			result.add(t2 as TypeVariable, t1);
			return UnificationResult.success(result);
		} 

		val error = result.unify(t1, t2);
		if(error !== null) {
			return UnificationResult.failure(new ValidationIssue(issue, error.message));
		}
		return UnificationResult.success(result);		
	}
	
	protected dispatch def UnificationIssue unify(Substitution substitution, IntegerType t1, IntegerType t2) {
		if(t1 != t2) {
			return new UnificationIssue(#[t1, t2], '''Types «t1» and «t2» are not the same.''');
		}
		return null;
	}
	
	protected dispatch def UnificationIssue unify(Substitution substitution, ProdType t1, ProdType t2) {
		if(t1.typeArguments.length != t2.typeArguments.length) {
			return new UnificationIssue(#[t1, t2], '''Types «t1» and «t2» differ in their number of arguments.''');
		}
		val issues = t1.typeArguments.tail.zip(t2.typeArguments.tail).map[t1_t2 |
			substitution.unify(t1_t2.key, t1_t2.value)
		].force
		return ComposedUnificationIssue.fromMultiple(issues);
	}
	
	protected dispatch def UnificationIssue unify(Substitution substitution, SumType t1, SumType t2) {
		if(t1.typeArguments.length != t2.typeArguments.length) {
			return new UnificationIssue(#[t1, t2], '''Types «t1» and «t2» are not the same.''');
		}
		val issues = t1.typeArguments.tail.zip(t2.typeArguments.tail).map[t1_t2 |
			substitution.unify(t1_t2.key, t1_t2.value)
		].force
		ComposedUnificationIssue.fromMultiple(issues);
	}
	
	protected dispatch def UnificationIssue unify(Substitution substitution, FunctionType t1, FunctionType t2) {
		val issues = #[
			substitution.unify(t1.from, t2.from),
			substitution.unify(t1.to, t2.to)
		]
		ComposedUnificationIssue.fromMultiple(issues);
	}
	
	protected dispatch def UnificationIssue unify(Substitution substitution, TypeVariable t1, AbstractType t2) {
		substitution.add(t1, t2);
		return null;
	}
	protected dispatch def UnificationIssue unify(Substitution substitution, AbstractType t1, TypeVariable t2) {
		substitution.add(t2, t1);
		return null;
	}
	
	protected dispatch def UnificationIssue unify(Substitution substitution, AtomicType t1, AtomicType t2) {
		if(t1.name != t2.name) {
			return new UnificationIssue(#[t1, t2], '''Types «t1» and «t2» are not the same.''');
		}
		
		// not an issue
		return null;
	}
	
	protected dispatch def UnificationIssue unify(Substitution substitution, TypeConstructorType t1, TypeConstructorType t2) {		
		if(t1.typeArguments.size !== t2.typeArguments.size) {
			return new UnificationIssue(#[t1, t2], '''Types «t1» and «t2» differ in their number of arguments.''')
		}
		
		val issues = (t1.typeArguments).zip(t2.typeArguments).map[t1_t2 |
			substitution.unify(t1_t2.key, t1_t2.value);
		].filterNull		
		// not an issue
		return ComposedUnificationIssue.fromMultiple(issues);
	}
	
	protected dispatch def UnificationIssue unify(Substitution substitution, AbstractType t1, AbstractType t2) {
		if(t1 != t2) { 
			return new UnificationIssue(#[t1, t2], '''Types «t1» and «t2» are not the same.''');
		}
	}
}