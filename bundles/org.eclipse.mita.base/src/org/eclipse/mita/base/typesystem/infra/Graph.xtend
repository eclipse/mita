package org.eclipse.mita.base.typesystem.infra

import com.google.common.base.Optional
import com.google.common.collect.HashBiMap
import java.util.ArrayList
import java.util.HashMap
import java.util.HashSet
import java.util.List
import java.util.Map
import java.util.Set
import java.util.Stack
import org.eclipse.xtend.lib.annotations.Accessors

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.init
import static extension org.eclipse.mita.base.util.BaseUtils.zip

@Accessors
class Graph<T> implements Cloneable {
	protected Map<Integer, Set<Integer>> outgoing = new HashMap();
	protected Map<Integer, Set<Integer>> incoming = new HashMap();
	
	protected Map<Integer, T> nodeIndex = new HashMap();
	protected Map<T, Set<Integer>> reverseMap = new HashMap();
	protected int nextNodeInt = 0;

	public override clone() {
		val c = super.clone() as Graph<T>;
		c.outgoing = new HashMap(c.outgoing);
		c.incoming = new HashMap(c.incoming);
		c.nodeIndex = new HashMap(c.nodeIndex);
		c.reverseMap = new HashMap(c.reverseMap);		
		
		return c;
	}
	
	def computeReverseMap() {
		reverseMap.clear();
		nodeIndex.entrySet.forEach[i_t |
			reverseMap.putIfAbsent(i_t.value, new HashSet());
			reverseMap.get(i_t.value).add(i_t.key);
		]
	}
	
	def getNodes() {
		return nodeIndex.values;
	}
	
	def addNode(T t) {
		if(t === null) {
			throw new NullPointerException;
		}
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
	
	def void addEdge(Integer fromIndex, Integer toIndex) {
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
		for(c: outgoing.get(v) ?: #[]) {
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
		val preds = incoming.get(nodeIdx) ?: #[];
		val succs = outgoing.get(nodeIdx) ?: #[];
		preds.forEach[outgoing.get(it).remove(nodeIdx)];
		succs.forEach[incoming.get(it).remove(nodeIdx)];
		incoming.remove(nodeIdx);
		outgoing.remove(nodeIdx);

		reverseMap.get(nodeIndex.get(nodeIdx)).remove(nodeIdx);
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
			val cycleEdges = cycleNodesOnly.init.zip(cycleNodesOnly.tail).force;
			val replacementNode = cycleCombiner.apply(cycleEdges);
			val replacementNodeIdx = _g.addNode(replacementNode);
			// a cycle contains one node twice: start and end. remove it here
			val cycleNodes = cycle.tail.toList;

			val p = cycleNodes.flatMap[_g.incoming.get(it.key)].filter[cycleNodes.findFirst[k_v | it == k_v.key] === null];
			val s = cycleNodes.flatMap[_g.outgoing.get(it.key)].filter[cycleNodes.findFirst[k_v | it == k_v.key] === null];
			
			// don't add edges to nodes that will be deleted
			p.reject[pred | cycleNodes.exists[it.key == pred]].forEach[_g.addEdge(it, replacementNodeIdx)];
			s.reject[succ | cycleNodes.exists[it.key == succ]].forEach[_g.addEdge(replacementNodeIdx, it)];
			
			// filter the new node in case the MGU is already in the graph. Then we would change edges to all point to the MGU and remove it afterwards, leaving a broken graph.
			cycleNodes.filter[it.key != replacementNodeIdx].forEach[_g.removeNode(it.key)];
			
			println(g.toGraphviz);		
			mbCycle = g.getCycle;
		} 
		return g;
	}
	
	def getPredecessors(Integer t) {
		return incoming.walk(new HashSet(), t) [ it ];
	}
	
	def getSuccessors(Integer t) {
		return outgoing.walk(new HashSet(), t) [ it ];
	}
	
	
	protected def <S> Iterable<S> walk(Map<Integer, Set<Integer>> g, T start, (T) => S visitor) {
		return reverseMap.get(start).flatMap[
			g.walk(new HashSet(), it, visitor)
		].force
	}
	protected def <S> Iterable<S> walk(Map<Integer, Set<Integer>> g, Set<Integer> visited, Integer idx, (T) => S visitor) {
		if(visited.contains(idx)) {
			return #[];
		}
		visited.add(idx);
		return (g.get(idx) ?: #[]).flatMap[
			val node = nodeIndex.get(it);
			g.walk(visited, it, visitor) + #[ visitor.apply(node) ]
		].force;
	}
	
	def replace(T from, T with) {
		if(reverseMap.containsKey(from)) {
			reverseMap.put(with, reverseMap.get(from));
			reverseMap.remove(from);		
		}
		nodeIndex.replaceAll([k, v | 
			if(v == from) {
				return with; 
			} else {
				return v;
			}])
	}
	
	/**
	 * @returns A pair of iterables of edges: outgoing and incoming
	 */
	def Pair<Iterable<Pair<Integer, Integer>>, Iterable<Pair<Integer, Integer>>> getEdges(Integer idx) {
		return outgoing.get(idx).map[ idx -> it ].force -> 
			   incoming.get(idx).map[ it -> idx ].force;
	}
	
	def nodeToString(Integer i) {
		val t = nodeIndex.get(i);
		return '''«t»(«i»)''';
	}
	
	def toGraphviz() {
		'''
		digraph G {
			«««FOR ft : nodes.flatMap[f| f.getBaseTypeSuccecessors().map[t| f -> t] ]»
			«FOR n_childs : outgoing.entrySet»
			«FOR child : n_childs.value»
			"«nodeToString(n_childs.key)»" -> "«nodeToString(child)»"; 
			«ENDFOR»
			«ENDFOR»
		}
		'''
	}
	def Iterable<Integer> looselyConnectedComponent(Integer integer) {
		return looselyConnectedComponentWalker(new HashSet(), integer);
	}
	protected def Set<Integer> looselyConnectedComponentWalker(Set<Integer> visited, Integer node) {
		if(visited.contains(node)) {
			return visited;
		}
		visited.add(node);
		return outgoing.get(node).fold(incoming.get(node).fold(visited, [v, n | looselyConnectedComponentWalker(v, n)]), [v, n | looselyConnectedComponentWalker(v, n)]);
	}
}