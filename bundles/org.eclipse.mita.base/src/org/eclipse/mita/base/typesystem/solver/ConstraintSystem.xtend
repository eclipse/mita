package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import java.util.ArrayList
import java.util.Collections
import java.util.List
import org.eclipse.mita.base.typesystem.ConstraintSystemProvider
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.Graph
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors

import static extension org.eclipse.mita.base.util.BaseUtils.force

@Accessors
class ConstraintSystem {
	@Inject protected ConstraintSystemProvider constraintSystemProvider; 
	protected List<AbstractTypeConstraint> constraints = new ArrayList;
	protected final SymbolTable symbolTable;
	protected Graph<AbstractType> explicitSubtypeRelations;

	new(SymbolTable symbolTable) {
		this.symbolTable = symbolTable;
		this.explicitSubtypeRelations = new Graph<AbstractType>() {
			
			override replace(AbstractType from, AbstractType with) {
				// in this graph when we replace we keep old nodes and do replacement on types (based on the fact that nodes contain AbstractTypes).
				// this means that for each node:
				// - get it
				// - if from is a typeVariable, do replacement on types 
				//   * if the resulting type differs by anything (compare by ===), get incoming and outgoing edges
				// - else compare for weak equality (==), on match get incoming and outcoming edges
				// - otherwise return nothing. Since we are in Java we get a List<Nullable Pair<AbstractType, Pair<Set<Integer>, Set<Integer>>>> instead of optionals. So filterNull to only get replacements.
				// this results in a list of triples which we then re-add to the graph.
				val newNodes = nodeIndex.keySet.map[
					val typ = nodeIndex.get(it);
					if(from instanceof TypeVariable) {
						val newTyp = typ.replace(from, with);
						if(newTyp !== typ) {
							return (newTyp -> (incoming.get(it) -> outgoing.get(it)));
						}
					}
					else if(typ == from) {
						return (with -> (incoming.get(it) -> outgoing.get(it)));
					}
					return null;
				].filterNull;
				newNodes.forEach([t__i_o | 
					val nt = t__i_o.key;
					val inc = t__i_o.value.key;
					val out = t__i_o.value.value;
					
					val idx = addNode(nt);
					inc.forEach[ i | 
						addEdge(i, idx);
					]
					out.forEach[ o | 
						addEdge(idx, o);
					]
				])
				return;
			}
		};
	}
	
	def void addConstraint(AbstractTypeConstraint constraint) {
		this.constraints.add(constraint);
	}
	
	def getSymbolTable() {
		return symbolTable;
	}
	
	def getConstraints() {
		return Collections.unmodifiableList(constraints);
	}
	
	override toString() {
		val res = new StringBuilder()
		
		res.append("Symbols:\n")
		res.append(symbolTable)
		res.append("\n\n")

		res.append("Constraints:\n")
		constraints.forEach[
			res.append("\t")
			res.append(it)
			res.append("\n")
		]
		
		return res.toString
	}
	
	def toGraphviz() {
		'''
		digraph G {
			«FOR c: constraints»
			«c.toGraphviz»
			«ENDFOR»
		}
		'''
	}
	
	def takeOne() {
		val result = new ConstraintSystem(symbolTable);
		if(constraints.empty) {
			return (null -> result);
		}
		
		result.constraints = constraints.tail.toList;
		return constraints.head -> result;
	}
	
	public def takeOneNonAtomic() {
		val result = new ConstraintSystem(symbolTable);
		result.constraintSystemProvider = constraintSystemProvider;
		val atomics = constraints.filter[constraintIsAtomic];
		val nonAtomics = constraints.filter[!constraintIsAtomic];
		if(nonAtomics.empty) {
			val x = hasNonAtomicConstraints;
			result.constraints = atomics.force;
			return (null -> result);
		}
		
		result.constraints = (nonAtomics.tail + atomics).force;
		return nonAtomics.head -> result;
	}
	
	public def hasNonAtomicConstraints() {
		return this.constraints.exists[!constraintIsAtomic];
	}
	
	public def constraintIsAtomic(AbstractTypeConstraint c) {
		(c instanceof SubtypeConstraint)
			&&((((c as SubtypeConstraint).subType instanceof TypeVariable) && (c as SubtypeConstraint).superType instanceof TypeVariable)
			|| (((c as SubtypeConstraint).subType instanceof TypeVariable) && (c as SubtypeConstraint).superType instanceof AbstractBaseType)
			|| (((c as SubtypeConstraint).subType instanceof AbstractBaseType) && (c as SubtypeConstraint).superType instanceof TypeVariable))
	}
	
	def plus(AbstractTypeConstraint constraint) {
		val result = new ConstraintSystem(symbolTable);
		result.constraints.add(constraint);
		result.constraints.addAll(this.constraints);
		return result;
	}
	
	def static combine(Iterable<ConstraintSystem> systems) {
		if(systems.empty) {
			return null;
		}
		
		val csp = systems.head.constraintSystemProvider;
		val result = systems.fold(csp.get(), [r, t|
			r.constraints.addAll(t.constraints);
			//r.symbolTable.content.putAll(t.symbolTable.content);
			return r;
		]);
		return csp.get() => [
			it.constraints.addAll(result.constraints.toSet);
			//it.symbolTable.content.putAll(result.symbolTable.content);
		]
	}
	
}
