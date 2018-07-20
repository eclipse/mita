package org.eclipse.mita.base.typesystem.solver

import com.google.common.collect.Lists
import com.google.inject.Inject
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import java.util.Set
import org.eclipse.mita.base.typesystem.ConstraintSystemProvider
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

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
	
	public override ConstraintSolution solve(ConstraintSystem system) {
		if(!system.isWeaklyUnifiable()) {
			return new ConstraintSolution(system, null, #[ new UnificationIssue(system, 'Subtype solving cannot terminate') ]);
		}
		
		val simplification = system.simplify(Substitution.EMPTY);
		if(!simplification.valid) {
			return new ConstraintSolution(simplification.system, simplification.substituion, #[simplification.issue]);
		}
		val simplifiedSystem = simplification.system;
		val simplifiedSubst = simplification.substituion;
		
		val constraintGraphAndSubst = simplifiedSystem.buildConstraintGraph(simplifiedSubst);
		if(!constraintGraphAndSubst.value.valid) {
			val failure = constraintGraphAndSubst.value;
			return new ConstraintSolution(simplification.system, failure.substituion, #[failure.issue]);
		}
		val constraintGraph = constraintGraphAndSubst.key;
		println(constraintGraph.toGraphviz());
		
		val resolvedGraphAndSubst = constraintGraph.resolve(constraintGraphAndSubst.value.substituion);
		if(!resolvedGraphAndSubst.value.valid) {
			val failure = resolvedGraphAndSubst.value;
			return new ConstraintSolution(simplification.system, failure.substituion, #[failure.issue]);
		}
		val resolvedGraph = resolvedGraphAndSubst.key;
		
		val solution = resolvedGraph.unify(resolvedGraphAndSubst.value.substituion);
		return new ConstraintSolution(simplification.system, solution.substituion, #[solution.issue].filterNull.toList);
	}
	
	protected def boolean isWeaklyUnifiable(ConstraintSystem system) {
		// TODO: implement me
		return true;
	}
	
	protected def SimplificationResult simplify(ConstraintSystem system, Substitution subtitution) {
		var resultSystem = system;
		var resultSub = subtitution;
		
		while(!resultSystem.hasAtomicConstraintsOnly()) {
			val constraintAndSystem = resultSystem.takeOne;
			val simplification = doSimplify(constraintAndSystem.value, resultSub, constraintAndSystem.key);
			if(!simplification.valid) {
				return simplification;
			}
			
			resultSystem = simplification.system;
			resultSub = simplification.substituion;
		}
		
		return SimplificationResult.success(resultSystem, resultSub);
	}
		
	def hasAtomicConstraintsOnly(ConstraintSystem system) {
		return !system.constraints.exists[
				(it instanceof SubtypeConstraint)
			&&(!(((it as SubtypeConstraint).subType instanceof TypeVariable) && (it as SubtypeConstraint).superType instanceof TypeVariable)
			|| !(((it as SubtypeConstraint).subType instanceof TypeVariable) && (it as SubtypeConstraint).superType instanceof AbstractBaseType)
			|| !(((it as SubtypeConstraint).subType instanceof AbstractBaseType) && (it as SubtypeConstraint).superType instanceof TypeVariable))
		];
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, EqualityConstraint constraint) {
		// unify
		val mgu = mguComputer.compute(constraint.left, constraint.right);
		if(!mgu.valid) {
			return SimplificationResult.failure(mgu.issue);
		}
		
		return SimplificationResult.success(mgu.substituion.apply(system), mgu.substituion.apply(substitution));
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint) {
		val sub = constraint.subType;
		val sup = constraint.superType;
		if(sub instanceof TypeConstructorType && sup instanceof TypeConstructorType) {
			// decompose:  Ct1...tn <: Cs1...sn
			val csub = sub as TypeConstructorType;
			val csup = sup as TypeConstructorType;
			if(csub.baseType != csup.baseType) {
				return SimplificationResult.failure(new UnificationIssue(#[csub, csup], "Can only decompose equal base types"));
			}
			if(csub.typeArguments.length !== csup.typeArguments.length) {
				return SimplificationResult.failure(new UnificationIssue(#[csub, csup], "Unequal number of type arguments"));
			}
			
			val ncs = constraintSystemProvider.get();
			csub.typeArguments.indexed.forEach[tsub_i|
				val tsub = tsub_i.value;
				val tsup = csup.typeArguments.get(tsub_i.key);
				ncs.addConstraint(csub.baseType.getVariance(tsub, tsup));
			];
			return SimplificationResult.success(ConstraintSystem.combine(#[ncs, system]), substitution);
		} else if(sub instanceof TypeVariable && sup instanceof TypeConstructorType) {
			// expand-l:   a <: Ct1...tn
			val expansion = (sup as TypeConstructorType).expand(sub as TypeVariable);
			val newSystem = expansion.apply(system.plus(new SubtypeConstraint(sub, sup)));
			val newSubstitution = expansion.apply(substitution);
			return SimplificationResult.success(newSystem, newSubstitution);
		} else if(sub instanceof TypeConstructorType && sup instanceof TypeVariable) {
			// expand-r:   Ct1...tn <: a
			val expansion = (sub as TypeConstructorType).expand(sup as TypeVariable);
			val newSystem = expansion.apply(system.plus(new SubtypeConstraint(sub, sup)));
			val newSubstitution = expansion.apply(substitution);
			return SimplificationResult.success(newSystem, newSubstitution);
		} else if(sub instanceof AbstractBaseType && sup instanceof AbstractBaseType) {
			// eliminate:  U <: T
			val issue = mguComputer.isSubtypeOf(sub, sup);
			if(issue === null) {
				return SimplificationResult.success(system, substitution);
			} else {
				return SimplificationResult.failure(issue);
			}
		}
	}
	
	protected def AbstractTypeConstraint getVariance(AbstractType baseType, AbstractType tau, AbstractType sigma) {
		// assume tau covariant to tau in baseType
		return new SubtypeConstraint(tau, sigma);
	}
	
	protected def Substitution expand(TypeConstructorType c, TypeVariable tv) {
		val newTypeVars = Lists.newArrayList(c.typeArguments.map[ new TypeVariable(it.origin) as AbstractType ]);
		val newCType = new TypeConstructorType(c.origin, 'nc_' + c.name, c.baseType, newTypeVars);
		return new Substitution() => [ it.add(tv, newCType) ];
	}

	protected def Pair<ConstraintGraph, UnificationResult> buildConstraintGraph(ConstraintSystem system, Substitution subtitution) {
		return new ConstraintGraph(system).removeCycles() -> UnificationResult.success(subtitution);
	}
	
	protected def Pair<ConstraintGraph, UnificationResult> resolve(ConstraintGraph graph, Substitution subtitution) {
		val vars = Lists.newArrayList(graph.typeVariables);
		for(v : vars) {
			val predecessors = graph.getBaseTypePredecessors(v);
			val supremum = graph.getSupremum(v);
			val successors = graph.getBaseTypeSuccecessors(v);
			val infimum = graph.getInfimum(v);
			val supremumIsValid = successors.forall[ it == supremum || graph.getBaseTypePredecessors(it).exists[ it == supremum ] ];
			val infimumIsValid = predecessors.forall[ it == infimum || graph.getBaseTypeSuccecessors(it).exists[ it == infimum ] ];
			
			if(!predecessors.empty) {
				if(supremum !== null && supremumIsValid) {
					// assign-sup
					graph.replace(v, supremum);
					subtitution.add(v, supremum);					
				} else {
					return null -> UnificationResult.failure(v, "Unable to find valid subtype for " + v.name);					
				}
			}
			if(!successors.empty) {
				if(infimum !== null && infimumIsValid) {
					// assign-inf
					graph.replace(v, infimum);
					subtitution.add(v, infimum);					
				} else {
					return null -> UnificationResult.failure(v, "Unable to find valid supertype for " + v.name);
				}
			}
		}
		return graph -> UnificationResult.success(subtitution);
	}
	
	protected def UnificationResult unify(ConstraintGraph graph, Substitution subtitution) {
		var result = subtitution;
		val losselyConnectedComponents = graph.typeVariables.flatMap[ graph.getEdges(it) ];
		for(w: losselyConnectedComponents) {
			val unification = mguComputer.compute(w.key, w.value);
			if(!unification.valid) {
				return unification;
			}
			result = unification.substituion.apply(result);
		}
		return UnificationResult.success(result);
	}

}

class ConstraintGraph {
	protected Map<Integer, Set<Integer>> outgoing = new HashMap();
	protected Map<Integer, Set<Integer>> incoming = new HashMap();
	
	protected Map<AbstractType, Integer> nodeIndex = new HashMap();
	protected Set<AbstractType> nodes = new HashSet();

	new(ConstraintSystem system) {
		system.constraints
			.filter(SubtypeConstraint)
			.forEach[ addEdge(it.subType, it.superType) ];
	}

	def addEdge(AbstractType from, AbstractType to) {
		if(!nodeIndex.containsKey(from)) {
			val idx = nodes.length;
			nodes.add(from);
			nodeIndex.put(from, idx);
		}
		if(!nodeIndex.containsKey(to)) {
			val idx = nodes.length;
			nodes.add(to);
			nodeIndex.put(to, idx);
		}
		
		val fromIndex = nodeIndex.get(from);
		val toIndex = nodeIndex.get(to);
		
		val outgoingAdjacencyList = outgoing.get(fromIndex) ?: new HashSet<Integer>();
		outgoingAdjacencyList.add(toIndex);
		outgoing.put(fromIndex, outgoingAdjacencyList);
		
		val incomingAdjacencyList = incoming.get(toIndex) ?: new HashSet<Integer>();
		incomingAdjacencyList.add(fromIndex);
		incoming.put(toIndex, incomingAdjacencyList);
	}

	def removeCycles() {
		// TODO: actually remove cycles and return new graph
		return this;
	}
	
	def getBaseTypePredecessors(AbstractType t) {
		return incoming.walk(t) [ it ]
	}

	def getBaseTypeSuccecessors(AbstractType t) {
		return outgoing.walk(t) [ it ]
	}
	
	def getSupremum(AbstractType t) {
		return t.baseTypeSuccecessors.findFirst[ (outgoing.get(it) ?: #[]).empty ]
	}
	
	def getInfimum(AbstractType t) {
		return t.getBaseTypePredecessors.findFirst[ (incoming.get(it) ?: #[]).empty ]
	}
	
	protected def <T> Iterable<T> walk(Map<Integer, Set<Integer>> g, AbstractType start, (AbstractType) => T visitor) {
		(g.get(start) ?: #[]).flatMap[
			val node = nodes.get(it);
			g.walk(node, visitor) + #[ visitor.apply(node) ]
		];
	}
	
	def getTypeVariables() {
		return nodes.filter(TypeVariable);
	}
	
	def replace(AbstractType from, AbstractType with) {
		val idx = nodeIndex.get(from);
		nodes.set(idx, with);
		nodeIndex.put(with, idx);
	}
	
	def getEdges(AbstractType t) {
		val idx = nodeIndex.get(t);
		return outgoing.get(idx).filter(AbstractType).map[ t -> it ] + incoming.get(idx).filter(AbstractType).map[ it -> t ];
	}
	
	def toGraphviz() {
		'''
		digraph G {
			«FOR ft : nodes.flatMap[f| f.getBaseTypeSuccecessors().map[t| f -> t] ]»
			"«ft.key»" ->"«ft.value»"; 
			«ENDFOR»
		}
		'''
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
