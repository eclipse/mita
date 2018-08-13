package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.mita.base.typesystem.ConstraintSystemProvider
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.ImplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.Graph
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

import static extension org.eclipse.mita.base.util.BaseUtils.*

/**
 * Solves coercive subtyping as described in 
 * Extending Hindley-Milner Type Inference with Coercive Structural Subtyping
 * Traytel et al., https://www21.in.tum.de/~nipkow/pubs/aplas11.pdf
 */
class CoerciveSubtypeSolver implements IConstraintSolver {
	@Inject
	protected MostGenericUnifierComputer mguComputer
	
	@Inject
	protected ConstraintSystemProvider constraintSystemProvider;
	
	@Inject 
	protected Provider<Substitution> substitutionProvider;
	
	@Inject
	protected ConstraintGraphProvider constraintGraphProvider;
	
	@Inject
	protected StdlibTypeRegistry typeRegistry;
	
	public override ConstraintSolution solve(ConstraintSystem system) {
		if(!system.isWeaklyUnifiable()) {
			return new ConstraintSolution(system, null, #[ new UnificationIssue(system, 'Subtype solving cannot terminate') ]);
		}
		println(system);
		println(system.toGraphviz);
		val simplification = system.simplify(Substitution.EMPTY);
		if(!simplification.valid) {
			return new ConstraintSolution(ConstraintSystem.combine(#[system, simplification.system].filterNull), simplification.substitution, #[simplification.issue]);
		}
		val simplifiedSystem = simplification.system;
		val simplifiedSubst = simplification.substitution;
		println(simplification);
		
		val constraintGraphAndSubst = simplifiedSystem.buildConstraintGraph(simplifiedSubst);
		if(!constraintGraphAndSubst.value.valid) {
			val failure = constraintGraphAndSubst.value;
			return new ConstraintSolution(ConstraintSystem.combine(#[system, simplification.system].filterNull), failure.substitution, #[failure.issue]);
		}
		val constraintGraph = constraintGraphAndSubst.key;
		val constraintGraphSubstitution = constraintGraphAndSubst.value.substitution;
		println(constraintGraph.toGraphviz());
		println(constraintGraphSubstitution);
		
		val resolvedGraphAndSubst = constraintGraph.resolve(constraintGraphSubstitution);
		if(!resolvedGraphAndSubst.value.valid) {
			val failure = resolvedGraphAndSubst.value;
			return new ConstraintSolution(ConstraintSystem.combine(#[system, simplification.system].filterNull), failure.substitution, #[failure.issue]);
		}
		val resolvedGraph = resolvedGraphAndSubst.key;
		val resolvedGraphSubstitution = resolvedGraphAndSubst.value.substitution;
		println(resolvedGraphSubstitution);
		
		val solution = resolvedGraph.unify(resolvedGraphSubstitution);
		println(solution);
		return new ConstraintSolution(ConstraintSystem.combine(#[system, simplification.system].filterNull), solution.substitution, #[solution.issue].filterNull.toList);
	}
	
	protected def boolean isWeaklyUnifiable(ConstraintSystem system) {
		// TODO: implement me
		return true;
	}
	
	protected def SimplificationResult simplify(ConstraintSystem system, Substitution subtitution) {
		var resultSystem = system;
		var resultSub = subtitution;
		
		while(resultSystem.hasNonAtomicConstraints()) {
			val constraintAndSystem = resultSystem.takeOneNonAtomic();
			val constraint = constraintAndSystem.key;

			val simplification = doSimplify(constraintAndSystem.value, resultSub, constraintAndSystem.key);
			if(!simplification.valid) {
				return simplification;
			}
			
			resultSub = simplification.substitution;
			resultSystem = resultSub.apply(simplification.system);
		}
		
		return SimplificationResult.success(resultSystem, resultSub);
	}
		
		
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, ExplicitInstanceConstraint constraint) {
		SimplificationResult.failure(new UnificationIssue(substitution, println('''CSS: doSimplify.ExplicitInstanceConstraint not implemented for «constraint»''')))
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, ImplicitInstanceConstraint constraint) {
		SimplificationResult.failure(new UnificationIssue(substitution, println('''CSS: doSimplify.ImplicitInstanceConstraint not implemented for «constraint»''')))
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, Object constraint) {
		SimplificationResult.failure(new UnificationIssue(substitution, println('''CSS: doSimplify not implemented for «constraint»''')))
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, Void constraint) {
		SimplificationResult.failure(new UnificationIssue(substitution, println('''CSS: doSimplify not implemented for null''')))
	}
	
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EqualityConstraint constraint) {
		// unify
		val mgu = mguComputer.compute(constraint.left, constraint.right);
		if(!mgu.valid) {
			return SimplificationResult.failure(mgu.issue);
		}
		
		return SimplificationResult.success(mgu.substitution.apply(system), mgu.substitution.apply(substitution));
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint) {
		val sub = constraint.subType;
		val top = constraint.superType;
		
		val result = doSimplify(system, substitution, constraint, sub, top);
		return result;
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, ProdType sub, SumType top) {
		val superTypesWithSameName = sub.superTypes.filter[it.name == top.name];
		if(sub.superTypes.contains(top)) {
			return SimplificationResult.success(system, substitution);
		} else if(superTypesWithSameName.size == 1) {
			return system.doSimplify(substitution, constraint, superTypesWithSameName.head, top);
		}
		else {
			//TODO: handle multiple super types with same name
			//already handled: superTypesWithSameName.empty --> failure
			return SimplificationResult.failure(new UnificationIssue(#[sub, top], '''CSS: «sub» is not a subtype of «top»'''))
		}
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, TypeConstructorType sub, TypeConstructorType top) {
		val typeArgs1 = sub.typeArguments.force;
		val typeArgs2 = top.typeArguments.force;
		if(typeArgs1.length !== typeArgs2.length) {
			return SimplificationResult.failure(new UnificationIssue(#[sub, top], '''CSS: «sub» and «top» differ in their type arguments'''));
		}
		if(sub.name != top.name) {
			return SimplificationResult.failure(new UnificationIssue(#[sub, top], '''CSS: «sub» and «top» are not constructed the same'''));
		}
		
		val typeArgs = sub.typeArguments.zip(top.typeArguments).indexed;
		val nc = constraintSystemProvider.get();
		typeArgs.forEach[i_t1t2 |
			val tIdx = i_t1t2.key;
			val tSub = i_t1t2.value.key;
			val tTop = i_t1t2.value.value;
			nc.addConstraint(sub.getVariance(tIdx, tSub, tTop));
		]
		
		return SimplificationResult.success(ConstraintSystem.combine(#[system, nc]), substitution);
		
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, TypeVariable sub, TypeConstructorType top) {
		// expand-l:   a <: Ct1...tn
		val expansion = substitutionProvider.get() => [top.expand(it, sub)];
		val newSystem = expansion.apply(system.plus(new SubtypeConstraint(sub, top)));
		val newSubstitution = expansion.apply(substitution);
		return SimplificationResult.success(newSystem, newSubstitution);
	} 
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, TypeConstructorType sub, TypeVariable top) {
		// expand-r:   Ct1...tn <: a
		val expansion = substitutionProvider.get() => [sub.expand(it, top)];
		val newSystem = expansion.apply(system.plus(new SubtypeConstraint(sub, top)));
		val newSubstitution = expansion.apply(substitution);
		return SimplificationResult.success(newSystem, newSubstitution);
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, AbstractBaseType sub, AbstractBaseType top) { 
		// eliminate:  U <: T
		val issue = typeRegistry.isSubtypeOf(sub, top);
		if(issue.present) {
			return SimplificationResult.failure(new UnificationIssue(#[sub, top], issue.get()));
		} else {
			return SimplificationResult.success(system, substitution);
		}
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, TypeScheme sub, AbstractType top) {
		val vars_instance = sub.instantiate
		val newSystem = system.plus(new SubtypeConstraint(vars_instance.value, top));
		return SimplificationResult.success(newSystem, substitution);
	} 
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, Object sub, Object top) {
		SimplificationResult.failure(new UnificationIssue(substitution, println('''CSS: doSimplify.SubtypeConstraint not implemented for «sub.class.simpleName» and «top.class.simpleName»''')))
	}
		
	protected def Pair<ConstraintGraph, UnificationResult> buildConstraintGraph(ConstraintSystem system, Substitution substitution) {
		val gWithCycles = constraintGraphProvider.get(system);
		println(gWithCycles.toGraphviz);
		val finalState = new Object() {
			var Substitution s = substitution;
			var Boolean success = true;
			var String msg = "";
			var Iterable<Pair<AbstractType, AbstractType>> origin = null;
		}
		val gWithoutCycles = Graph.removeCycles(gWithCycles, [cycle | 
			val mgu = mguComputer.compute(cycle); 
			if(mgu.valid) {
				val newTypes = mgu.substitution.applyToTypes(cycle.flatMap[t1_t2 | #[t1_t2.key, t1_t2.value]]);
				finalState.s = finalState.s.apply(mgu.substitution);
				return newTypes.head;
			}
			else {
				finalState.success = false;
				finalState.origin = cycle.toList;
				finalState.msg = '''CSS: Cyclic dependencies could not be resolved: «finalState.origin.map[it.key.origin ?: it.key].join(' ⩽ ')»''';
				return new BottomType(null, finalState.msg);
			}
		])
		if(finalState.success) {
			return (gWithoutCycles -> UnificationResult.success(finalState.s));
		}
		else {
			return (gWithoutCycles -> UnificationResult.failure(finalState.origin, finalState.msg));
		}
	}
	
	protected def Pair<ConstraintGraph, UnificationResult> resolve(ConstraintGraph graph, Substitution subtitution) {
		val varIdxs = graph.typeVariables;
		for(vIdx : varIdxs) {
			val v = graph.nodeIndex.get(vIdx) as TypeVariable;
			val predecessors = graph.getBaseTypePredecessors(vIdx);
			val supremum = graph.getSupremum(predecessors);
			val successors = graph.getBaseTypeSuccecessors(vIdx);
			val infimum = graph.getInfimum(successors);
			val supremumIsValid = supremum !== null && successors.forall[ t | typeRegistry.isSubType(supremum, t) ];
			val infimumIsValid = infimum !== null && predecessors.forall[ t | typeRegistry.isSubType(t, infimum) ];
						
			if(!predecessors.empty) {
				if(supremumIsValid) {
					// assign-sup
					graph.replace(v, supremum);
					subtitution.add(v, supremum);
				} else {
					//redo for debugging
					graph.getBaseTypePredecessors(vIdx);
					graph.getSupremum(predecessors);
					supremum !== null && successors.forall[ t | 
						typeRegistry.isSubType(supremum, t)
					];
					return null -> UnificationResult.failure(v, "Unable to find valid subtype for " + v.name);					
				}
			}
			else if(!successors.empty) {
				if(infimumIsValid) {
					// assign-inf
					graph.replace(v, infimum);
					subtitution.add(v, infimum);
				} else {
					return null -> UnificationResult.failure(v, "Unable to find valid supertype for " + v.name);
				}
			}
			println(graph.toGraphviz);
		}
		return graph -> UnificationResult.success(subtitution);
	}
	
	protected def UnificationResult unify(ConstraintGraph graph, Substitution substitution) {
		val loselyConnectedComponents = graph.typeVariables.map[graph.looselyConnectedComponent(it)].toSet;
		loselyConnectedComponents.map[it.map[ni | graph.nodeIndex.get(ni)].toList].fold(UnificationResult.success(substitution), [ur, lcc |
			if(ur.valid === false) {
				return ur;
			}
			val lccEdges = lcc.tail.zip(lcc.init);
			val sub = ur.substitution;
			return unify(lccEdges, sub);
		])
	}
	protected def UnificationResult unify(Iterable<Pair<AbstractType, AbstractType>> loselyConnectedComponents, Substitution substitution) {
		var result = substitution;
		for(w: loselyConnectedComponents) {
			val unification = mguComputer.compute(w.key, w.value);
			if(!unification.valid) {
				return unification;
			}
			result = unification.substitution.apply(result);
		}
		return UnificationResult.success(result);
	}

}

class ConstraintGraphProvider implements Provider<ConstraintGraph> {
	
	@Inject 
	StdlibTypeRegistry typeRegistry;
	
	@Inject
	ConstraintSystemProvider constraintSystemProvider;
	
	override get() {
		return new ConstraintGraph(constraintSystemProvider.get(), typeRegistry);
	}
	
	def get(ConstraintSystem system) {
		return new ConstraintGraph(system, typeRegistry);
	}
}

class ConstraintGraph extends Graph<AbstractType> {
	
	protected val StdlibTypeRegistry typeRegistry;
	
	new(ConstraintSystem system, StdlibTypeRegistry typeRegistry) {
		this.typeRegistry = typeRegistry;
		system.constraints
			.filter(SubtypeConstraint)
			.forEach[ addEdge(it.subType, it.superType) ];
	}
	def getTypeVariables() {
		return nodeIndex.filter[k, v| v instanceof TypeVariable].keySet;
	}
	def getBaseTypePredecessors(Integer t) {
		return getPredecessors(t).filter(AbstractBaseType)
	}

	def getBaseTypeSuccecessors(Integer t) {
		return getSuccessors(t).filter(AbstractBaseType)
	}
	
	def <T extends AbstractType> getSupremum(Iterable<T> ts) {
		val tsCut = ts.map[
			typeRegistry.getSuperTypes(it).toSet
		].reduce[s1, s2| s1.reject[!s2.contains(it)].toSet] ?: #[].toSet; // cut over emptySet is emptySet
		return tsCut.findFirst[candidate | 
			tsCut.forall[u | 
				typeRegistry.isSubType(candidate, u)
			]
		];
	}
	
	def <T extends AbstractType> getInfimum(Iterable<T> ts) {
		val tsCut = ts.map[typeRegistry.getSubTypes(it).toSet].reduce[s1, s2| s1.reject[!s2.contains(it)].toSet] ?: #[].toSet;
		return tsCut.findFirst[candidate | tsCut.forall[l | typeRegistry.isSubType(l, candidate)]];
	}
	
	def getSupremum(AbstractType t) {
		return getSupremum(#[t])
	}
	
	def getInfimum(AbstractType t) {
		return getInfimum(#[t])
	}
	
	override nodeToString(Integer i) {
		val t = nodeIndex.get(i);
		if(t?.origin === null) {
			return super.nodeToString(i)	
		}
		return '''«t.origin»(«t», «i»)'''
	}
	
	override addEdge(Integer fromIndex, Integer toIndex) {
		if(fromIndex == toIndex) {
			return;
		}
		super.addEdge(fromIndex, toIndex);
	}
} 

@FinalFieldsConstructor
@Accessors
class SimplificationResult extends UnificationResult {
	protected final ConstraintSystem system;
	
	static def success(ConstraintSystem s, Substitution sigma) {
		return new SimplificationResult(sigma, null, s);
	}
	
	static def SimplificationResult failure(UnificationIssue issue) {
		return new SimplificationResult(null, issue, null);
	}
}
