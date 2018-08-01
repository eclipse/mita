package org.eclipse.mita.base.typesystem.solver

import com.google.common.base.Optional
import com.google.common.collect.HashBiMap
import com.google.common.collect.Lists
import com.google.inject.Inject
import com.google.inject.Provider
import java.util.ArrayList
import java.util.HashMap
import java.util.HashSet
import java.util.List
import java.util.Map
import java.util.Set
import java.util.Stack
import org.eclipse.mita.base.typesystem.ConstraintSystemProvider
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.ImplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.ProdType
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
	
	public override ConstraintSolution solve(ConstraintSystem system) {
		if(!system.isWeaklyUnifiable()) {
			return new ConstraintSolution(system, null, #[ new UnificationIssue(system, 'Subtype solving cannot terminate') ]);
		}
		
		val simplification = system.simplify(Substitution.EMPTY);
		if(!simplification.valid) {
			return new ConstraintSolution(ConstraintSystem.combine(#[system, simplification.system].filterNull), simplification.substitution, #[simplification.issue]);
		}
		val simplifiedSystem = simplification.system;
		val simplifiedSubst = simplification.substitution;
		
		val constraintGraphAndSubst = simplifiedSystem.buildConstraintGraph(simplifiedSubst);
		if(!constraintGraphAndSubst.value.valid) {
			val failure = constraintGraphAndSubst.value;
			return new ConstraintSolution(ConstraintSystem.combine(#[system, simplification.system].filterNull), failure.substitution, #[failure.issue]);
		}
		val constraintGraph = constraintGraphAndSubst.key;
		println(constraintGraph.toGraphviz());
		
		val resolvedGraphAndSubst = constraintGraph.resolve(constraintGraphAndSubst.value.substitution);
		if(!resolvedGraphAndSubst.value.valid) {
			val failure = resolvedGraphAndSubst.value;
			return new ConstraintSolution(ConstraintSystem.combine(#[system, simplification.system].filterNull), failure.substitution, #[failure.issue]);
		}
		val resolvedGraph = resolvedGraphAndSubst.key;
		
		val solution = resolvedGraph.unify(resolvedGraphAndSubst.value.substitution);
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
			val constraintAndSystem = resultSystem.takeOneNonAtomic;
			val constraint = constraintAndSystem.key;
			if(constraint instanceof SubtypeConstraint) {
				if(constraint.atomic) {
					resultSystem.takeOneNonAtomic;
				}
			}
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
		SimplificationResult.failure(new UnificationIssue(substitution, println('''doSimplify.ExplicitInstanceConstraint not implemented for «constraint»''')))
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, ImplicitInstanceConstraint constraint) {
		SimplificationResult.failure(new UnificationIssue(substitution, println('''doSimplify.ImplicitInstanceConstraint not implemented for «constraint»''')))
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, Object constraint) {
		SimplificationResult.failure(new UnificationIssue(substitution, println('''doSimplify not implemented for «constraint»''')))
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, Void constraint) {
		SimplificationResult.failure(new UnificationIssue(substitution, println('''doSimplify not implemented for null''')))
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
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, TypeConstructorType sub, TypeConstructorType top) {
		
		// decompose:  Ct1...tn <: Cs1...sn
		if(sub.baseType != top.baseType) {
			return SimplificationResult.failure(new UnificationIssue(#[sub, top], "Can only decompose equal base types"));
		}
		if(sub.typeArguments.length !== top.typeArguments.length) {
			return SimplificationResult.failure(new UnificationIssue(#[sub, top], "Unequal number of type arguments"));
		}
		
		val ncs = constraintSystemProvider.get();
		sub.typeArguments.zip(top.typeArguments).forEach[s_t |
			val tsub = s_t.key;
			val tsup = s_t.value;
			ncs.addConstraint(sub.baseType.getVariance(tsub, tsup));
		];
		return SimplificationResult.success(ConstraintSystem.combine(#[ncs, system]), substitution);
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, TypeVariable sub, TypeConstructorType top) {
		// expand-l:   a <: Ct1...tn
		val expansion = top.expand(sub);
		val newSystem = expansion.apply(system.plus(new SubtypeConstraint(sub, top)));
		val newSubstitution = expansion.apply(substitution);
		return SimplificationResult.success(newSystem, newSubstitution);
	} 
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, TypeConstructorType sub, TypeVariable top) {
		// expand-r:   Ct1...tn <: a
		val expansion = sub.expand(top);
		val newSystem = expansion.apply(system.plus(new SubtypeConstraint(sub, top)));
		val newSubstitution = expansion.apply(substitution);
		return SimplificationResult.success(newSystem, newSubstitution);
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, AbstractBaseType sub, AbstractBaseType top) { 
		// eliminate:  U <: T
		val issue = mguComputer.isSubtypeOf(sub, top);
		if(issue === null) {
			return SimplificationResult.success(system, substitution);
		} else {
			return SimplificationResult.failure(issue);
		}
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, TypeScheme sub, AbstractType top) {
		val vars_instance = sub.instantiate
		val newSystem = system.plus(new SubtypeConstraint(vars_instance.value, top));
		return SimplificationResult.success(newSystem, substitution);
	} 
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, FunctionType sub, FunctionType top) { 
		//    fa :: a -> b   <:   fb :: c -> d 
		// ⟺ every fa can be used as fb 
		// ⟺ b >: d ∧    a <: c
		val newSystem = system.plus(new SubtypeConstraint(top.from, sub.from)).plus(new SubtypeConstraint(sub.to, top.to));		
		return SimplificationResult.success(newSystem, substitution);
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, TypeVariable sub, FunctionType top) { 
		// expand-l:   a <: Ct1...tn
		val expansion = top.expand(sub);
		val newSystem = expansion.apply(system.plus(new SubtypeConstraint(sub, top)));
		val newSubstitution = expansion.apply(substitution);
		return SimplificationResult.success(newSystem, newSubstitution);
	}
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, FunctionType sub, TypeVariable top) { 
		// expand-r:   Ct1...tn <: a
		val expansion = sub.expand(top);
		val newSystem = expansion.apply(system.plus(new SubtypeConstraint(sub, top)));
		val newSubstitution = expansion.apply(substitution);
		return SimplificationResult.success(newSystem, newSubstitution);
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, ProdType sub, ProdType top) { 
		if(sub.types.length < top.types.length) {
			return SimplificationResult.failure(new UnificationIssue(substitution, '''subtype has less fields than super type'''));
		}
		
		val ncs = constraintSystemProvider.get();
		
		sub.types.zip(top.types).forEach[s_t|
			val tsub = s_t.key;
			val tsup = s_t.value;
			ncs.addConstraint(new SubtypeConstraint(tsub, tsup));
		]
		return SimplificationResult.success(ConstraintSystem.combine(#[ncs, system]), substitution);
	}
	
	protected dispatch def SimplificationResult doSimplify(ConstraintSystem system, Substitution substitution, SubtypeConstraint constraint, Object sub, Object top) {
		SimplificationResult.failure(new UnificationIssue(substitution, println('''doSimplify.SubtypeConstraint not implemented for «sub.class.simpleName» and «top.class.simpleName»''')))
	}
	
	protected def AbstractTypeConstraint getVariance(AbstractType baseType, AbstractType tau, AbstractType sigma) {
		// assume tau covariant to tau in baseType
		return new SubtypeConstraint(tau, sigma);
	}
	
	protected def Substitution expand(TypeConstructorType c, TypeVariable tv) {
		val newTypeVars = Lists.newArrayList(c.typeArguments.map[ new TypeVariable(it.origin) as AbstractType ]).force;
		val newCType = new TypeConstructorType(c.origin, 'nc_' + c.name, c.baseType, newTypeVars);
		return substitutionProvider.get() => [ it.add(tv, newCType) ];
	}
	
	protected def Substitution expand(FunctionType f, TypeVariable tv) {
		val newCType = new FunctionType(f.origin, new TypeVariable(f.from.origin), new TypeVariable(f.to.origin));
		return substitutionProvider.get() => [ it.add(tv, newCType) ];
	}

	protected def Pair<ConstraintGraph, UnificationResult> buildConstraintGraph(ConstraintSystem system, Substitution substitution) {
		val gWithCycles = new ConstraintGraph(system);
		println(gWithCycles.toGraphviz);
		val substitutionHolder = new Object() {
			var s = substitution;
		}
		val gWithoutCycles = Graph.removeCycles(gWithCycles, [cycle | 
			val mgu = unify(cycle, substitutionHolder.s); 
			if(mgu.valid) {
				val newTypes = mgu.substitution.applyToTypes(cycle.flatMap[t1_t2 | #[t1_t2.key, t1_t2.value]]);
				substitutionHolder.s = substitutionHolder.s.apply(mgu.substitution);
				return newTypes.head;
			}
		])
		return (gWithoutCycles -> UnificationResult.success(substitutionHolder.s));
	}
	
	protected def Pair<ConstraintGraph, UnificationResult> resolve(ConstraintGraph graph, Substitution subtitution) {
		val vars = Lists.newArrayList(graph.typeVariables);
		for(v : vars) {
			val predecessors = graph.getBaseTypePredecessors(v);
			val supremum = graph.getSupremum(predecessors);
			val successors = graph.getBaseTypeSuccecessors(v);
			val infimum = graph.getInfimum(successors);
			val supremumIsValid = successors.forall[ t | graph.isSubType(supremum, t) ];
			val infimumIsValid = predecessors.forall[ t | graph.isSubType(t, infimum) ];
			
			if(!predecessors.empty) {
				if(supremum !== null && supremumIsValid) {
					// assign-sup
					graph.replace(v, supremum);
					subtitution.add(v, supremum);
				} else {
					return null -> UnificationResult.failure(v, "Unable to find valid subtype for " + v.name);					
				}
			}
			else if(!successors.empty) {
				if(infimum !== null && infimumIsValid) {
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
		val loselyConnectedComponents = graph.typeVariables.map[graph.getEdges(it)].flatMap[it.key + it.value];
		return unify(loselyConnectedComponents, substitution);
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

class ConstraintGraph extends Graph<AbstractType> {
	new(ConstraintSystem system) {
		system.constraints
			.filter(SubtypeConstraint)
			.forEach[ addEdge(it.subType, it.superType) ];
	}
	def getTypeVariables() {
		return nodes.filter(TypeVariable);
	}
	def getBaseTypePredecessors(AbstractType t) {
		return getPredecessors(t).filter(AbstractBaseType)
	}

	def getBaseTypeSuccecessors(AbstractType t) {
		return getSuccessors(t).filter(AbstractBaseType)
	}
	def getSuperTypes(AbstractType t) {
		return getSuccessors(t) + #[t];
	}
	def getSubTypes(AbstractType t) {
		return getPredecessors(t) + #[t];
	}
	def isSubType(AbstractType sub, AbstractType top) {
		return sub.getSuperTypes.toSet.contains(top);
	}
	
	def <T extends AbstractType> getSupremum(Iterable<T> ts) {
		val tsCut = ts.map[it.getSuperTypes.toSet].reduce[s1, s2| s1.reject[!s2.contains(it)].toSet] ?: #[].toSet; // cut over emptySet is emptySet
		return tsCut.findFirst[candidate | tsCut.forall[u | candidate.isSubType(u)]];
	}
	
	def <T extends AbstractType> getInfimum(Iterable<T> ts) {
		val tsCut = ts.map[it.getSubTypes.toSet].reduce[s1, s2| s1.reject[!s2.contains(it)].toSet] ?: #[].toSet;
		return tsCut.findFirst[candidate | tsCut.forall[l | l.isSubType(candidate)]];
	}
	
	def getSupremum(AbstractType t) {
		return getSupremum(#[t])
		//return t.baseTypeSuccecessors.findFirst[ (outgoing.get(it) ?: #[]).empty ]
	}
	
	def getInfimum(AbstractType t) {
		return getInfimum(#[t])
		//return t.getBaseTypePredecessors.findFirst[ (incoming.get(it) ?: #[]).empty ]
	}
}

class Graph<T> implements Cloneable {
	protected Map<Integer, Set<Integer>> outgoing = new HashMap();
	protected Map<Integer, Set<Integer>> incoming = new HashMap();
	
	protected Map<Integer, T> nodeIndex = new HashMap();
	protected Map<T, Set<Integer>> reverseMap = new HashMap();
	protected int nextNodeInt = 0;

	protected new() {}
	public override clone() {
		val c = super.clone() as Graph<T>;
		c.outgoing = new HashMap(c.outgoing);
		c.incoming = new HashMap(c.incoming);
		c.nodeIndex = new HashMap(c.nodeIndex);
		c.reverseMap = new HashMap(c.reverseMap);		
		
		return c;
	}
	
	def getNodes() {
		return nodeIndex.values;
	}
	
	def addNode(T t) {
		if(!reverseMap.containsKey(t)) {
			val idx = nextNodeInt++;
			reverseMap.put(t, new HashSet(#[idx]))
		}
		val idx = reverseMap.get(t).head
		
		if(!nodeIndex.containsKey(idx)) {
			nodeIndex.put(idx, t);
		}
		
		if(!outgoing.containsKey(idx)) {
			outgoing.put(idx, new HashSet<Integer>());
		}
		if(!incoming.containsKey(idx)) {
			incoming.put(idx, new HashSet<Integer>());
		}
		return idx;
	}
	
	def addEdge(Integer fromIndex, Integer toIndex) {
		val outgoingAdjacencyList = outgoing.get(fromIndex) ?: new HashSet<Integer>();
		outgoingAdjacencyList.add(toIndex);
		outgoing.put(fromIndex, outgoingAdjacencyList);
		
		val incomingAdjacencyList = incoming.get(toIndex) ?: new HashSet<Integer>();
		incomingAdjacencyList.add(fromIndex);
		incoming.put(toIndex, incomingAdjacencyList);
	}
	
	def addEdge(T from, T to) {		
		val fromIndex = addNode(from)
		val toIndex = addNode(to);
		
		addEdge(fromIndex, toIndex);
	}

	def Optional<List<Integer>> getCycleHelper(Integer v, Set<Integer> visited, Stack<Integer> recStack) {
		if(recStack.contains(v)) {
			return Optional.of(getCycle(recStack, v));
		}
		if(visited.contains(v)) {
			return Optional.absent;
		}
		
		visited.add(v);
		recStack.push(v);
		for(c: outgoing.get(v)) {
			val mbCycle = getCycleHelper(c, visited, recStack);
			if(mbCycle.present) {
				return mbCycle;
			}
		}
		recStack.pop();
		return Optional.absent;
	}
	
	static def <T> getCycle(Stack<T> stack, T v) {
		var result = new ArrayList<T>(#[v]);
		while(stack.peek != v) {
			result.add(stack.pop)
		}
		result.add(v);
		result.reverse;
		return result;
	}
	
	def getCycle() {
		for(v : nodeIndex.keySet) {
			val mbCycle = getCycleHelper(v, new HashSet(), new Stack());
			if(mbCycle.present) {
				return mbCycle
			}
		}
		return Optional.absent;
	} 
	
	def removeNode(Integer nodeIdx) {
		incoming.remove(nodeIdx);
		outgoing.remove(nodeIdx);
		reverseMap.remove(nodeIndex.get(nodeIdx));
		nodeIndex.remove(nodeIdx);
	}
		
	def static <S, T extends Graph<S>> T removeCycles(T g0, (Iterable<Pair<S, S>>)=>S cycleCombiner) {
		var g = g0.clone() as T;
		var mbCycle = g.getCycle;
		while(mbCycle.present) {
			val _g = g;
			val biMap = HashBiMap.create(g.nodeIndex);
			val cycle = mbCycle.get.map[it -> _g.nodeIndex.get(it)];
			val cycleNodesOnly = mbCycle.get.map[_g.nodeIndex.get(it)];
			val cycleEdges = cycleNodesOnly.init.zip(cycleNodesOnly.tail);
			val replacementNode = cycleCombiner.apply(cycleEdges);
			// a cycle contains one node twice: start and end. remove it here
			val cycleNodes = cycle.tail.toList;
			val p = cycleNodes.flatMap[_g.incoming.get(it.key)].filter[cycleNodes.findFirst[k_v | it == k_v.key] === null]
			val s = cycleNodes.flatMap[_g.outgoing.get(it.key)].filter[cycleNodes.findFirst[k_v | it == k_v.key] === null]
			p.forEach[_g.addEdge(it, _g.addNode(replacementNode))];
			s.forEach[_g.addEdge(_g.addNode(replacementNode), it)];
			
			cycleNodes.forEach[_g.removeNode(it.key)];
			
			println(g.toGraphviz);		
			mbCycle = g.getCycle;
		} 
		return g;
	}
	
	def getPredecessors(T t) {
		return incoming.walk(t) [ it ];
	}
	
	def getSuccessors(T t) {
		return outgoing.walk(t) [ it ];
	}
	
	
	protected def <S> Iterable<S> walk(Map<Integer, Set<Integer>> g, T start, (T) => S visitor) {
		return reverseMap.get(start).flatMap[g.walk(it, visitor)].force
	}
	protected def <S> Iterable<S> walk(Map<Integer, Set<Integer>> g, Integer idx, (T) => S visitor) {
		return (g.get(idx) ?: #[]).flatMap[
			val node = nodeIndex.get(it);
			g.walk(it, visitor) + #[ visitor.apply(node) ]
		].force;
	}
	
	def replace(T from, T with) {
		nodeIndex.replaceAll([k, v | if(v == from) with else v])
	}
	
	/**
	 * @returns A pair of iterables of edges: outgoing and incoming
	 */
	def Pair<Iterable<Pair<T, T>>, Iterable<Pair<T, T>>> getEdges(T t) {
		val idx = addNode(t);
		return outgoing.get(idx).map[ t -> nodeIndex.get(it) ] -> 
			   incoming.get(idx).map[ nodeIndex.get(it) -> t ];
	}
	
	def toGraphviz() {
		'''
		digraph G {
			«««FOR ft : nodes.flatMap[f| f.getBaseTypeSuccecessors().map[t| f -> t] ]»
			«FOR n_childs : outgoing.entrySet»
			«FOR child : n_childs.value»
			"«n_childs.key»(«nodeIndex.get(n_childs.key)»)" -> "«child»(«nodeIndex.get(child)»)"; 
			«ENDFOR»
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
