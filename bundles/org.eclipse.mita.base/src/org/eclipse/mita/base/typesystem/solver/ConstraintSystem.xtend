package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.ArrayList
import java.util.Collections
import java.util.HashMap
import java.util.List
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.JavaClassInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.constraints.TypeClassConstraint
import org.eclipse.mita.base.typesystem.infra.Graph
import org.eclipse.mita.base.typesystem.infra.TypeClass
import org.eclipse.mita.base.typesystem.infra.TypeVariableAdapter
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.serialization.SerializationAdapter
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.xtext.util.OnChangeEvictingCache

import static extension org.eclipse.mita.base.util.BaseUtils.force
import org.eclipse.mita.base.typesystem.infra.TypeClassProxy

@Accessors
class ConstraintSystem {
	@Inject protected Provider<ConstraintSystem> constraintSystemProvider; 
	@Inject protected SerializationAdapter serializationAdapter;
	protected List<AbstractTypeConstraint> constraints = new ArrayList;
	protected Map<QualifiedName, TypeClass> typeClasses = new HashMap();

	// not use atm - is not passed through/serialized in the index
	protected Graph<AbstractType> explicitSubtypeRelations;
	
	new() {
		
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
				].filterNull.force;
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
	
	def TypeClass getTypeClassOrNull(QualifiedName qn) {
		return typeClasses.get(qn);
	}
	def TypeClass getTypeClass(QualifiedName qn, Iterable<Pair<AbstractType, EObject>> candidates) {
		if(!typeClasses.containsKey(qn)) {
			val typeClass = new TypeClass(candidates);
			typeClasses.put(qn, typeClass);
		}
		return typeClasses.get(qn);
	}
	def TypeClass getTypeClassProxy(QualifiedName qn, TypeVariableProxy tvProxy) {
		if(!typeClasses.containsKey(qn)) {
			val typeClass = new TypeClassProxy(tvProxy);
			typeClasses.put(qn, typeClass);
		}
		return typeClasses.get(qn);
	}
		
	def getConstraints() {
		return Collections.unmodifiableList(constraints);
	}
	
	override toString() {
		val res = new StringBuilder()
		
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
		val result = constraintSystemProvider?.get() ?: new ConstraintSystem();
		if(constraints.empty) {
			return (null -> result);
		}
		
		result.constraints = constraints.tail.toList;
		result.explicitSubtypeRelations = explicitSubtypeRelations;
		result.typeClasses = typeClasses;
		return constraints.head -> result;
	}
	
	def takeOneNonAtomic() {
		val result = constraintSystemProvider?.get() ?: new ConstraintSystem();
		result.constraintSystemProvider = constraintSystemProvider;
		val atomics = constraints.filter[constraintIsAtomic];
		val nonAtomics = constraints.filter[!constraintIsAtomic];
		if(nonAtomics.empty) {
			result.constraints = atomics.force;
			return (null -> result);
		}
		
		result.constraints = (nonAtomics.tail + atomics).force;
		result.explicitSubtypeRelations = explicitSubtypeRelations;
		result.typeClasses = typeClasses;
		return nonAtomics.head -> result;
	}
	
	def hasNonAtomicConstraints() {
		return this.constraints.exists[!constraintIsAtomic];
	}
	
	def constraintIsAtomic(AbstractTypeConstraint c) {
		(
			(c instanceof SubtypeConstraint)
			&& (
				(((c as SubtypeConstraint).subType instanceof TypeVariable) && (c as SubtypeConstraint).superType instanceof TypeVariable)
			 || (((c as SubtypeConstraint).subType instanceof TypeVariable) && (c as SubtypeConstraint).superType instanceof AbstractBaseType)
			 || (((c as SubtypeConstraint).subType instanceof AbstractBaseType) && (c as SubtypeConstraint).superType instanceof TypeVariable)
			)	
		)
		|| (
			(c instanceof TypeClassConstraint)
			&& (
				(!(c as TypeClassConstraint).types.flatMap[it.freeVars].empty)
			)
		)
		|| (
			(c instanceof ExplicitInstanceConstraint)
			&& (
				(c as ExplicitInstanceConstraint).typeScheme instanceof TypeVariable
			)
		)
		|| (
			(c instanceof JavaClassInstanceConstraint)
			&& (
				(c as JavaClassInstanceConstraint).what instanceof TypeVariable
			)
		)
	}
	
	def plus(AbstractTypeConstraint constraint) {
		val result = constraintSystemProvider?.get() ?: new ConstraintSystem();
		result.constraintSystemProvider = constraintSystemProvider;
		result.constraints.add(constraint);
		return ConstraintSystem.combine(#[this, result]);
	}
	
	def static combine(Iterable<ConstraintSystem> systems) {
		if(systems.empty) {
			return null;
		}
		
		val csp = systems.map[it.constraintSystemProvider].filterNull.head;
		val result = systems.fold(csp?.get() ?: new ConstraintSystem(), [r, t|
			r.constraints.addAll(t.constraints);
			r.typeClasses.putAll(t.typeClasses);
			t.explicitSubtypeRelations => [g | g.nodes.forEach[typeNode | 
				g.reverseMap.get(typeNode).forEach[typeIdx |
					g.getPredecessors(typeIdx).forEach[r.explicitSubtypeRelations.addEdge(it, typeNode)]
					g.getSuccessors(typeIdx).forEach[r.explicitSubtypeRelations.addEdge(typeNode, it)]
				]
			]]
			//r.symbolTable.content.putAll(t.symbolTable.content);
			return r;
		]);
		return csp.get() => [
			it.constraintSystemProvider = csp;
			it.constraints.addAll(result.constraints.toSet);
			it.typeClasses = result.typeClasses
			it.explicitSubtypeRelations = result.explicitSubtypeRelations
			//it.symbolTable.content.putAll(result.symbolTable.content);
		]
	}
	
	def replace(Substitution substitution) {
		val newConstraints = new ArrayList();
		newConstraints.addAll(constraints.map[ it.replace(substitution) ]);
		this.constraints = newConstraints;
		return this;
	}
	
	def ConstraintSystem replaceProxies(Resource resource, IScopeProvider scopeProvider) {
		val result = constraintSystemProvider.get();
		result.constraints += constraints.map[ it.replaceProxies[ this.resolveProxy(it, resource, scopeProvider).head ] ].force;
		result.typeClasses.putAll(typeClasses.mapValues[ it.replaceProxies([ this.resolveProxy(it, resource, scopeProvider) ], [resource.resourceSet.getEObject(it, false)]) ]);
		result.explicitSubtypeRelations = explicitSubtypeRelations.clone() as Graph<AbstractType>;
		return result;
	}
	
	protected def Iterable<AbstractType> resolveProxy(TypeVariableProxy tvp, Resource resource, IScopeProvider scopeProvider) {
		if(tvp.origin === null) {
			return #[new BottomType(tvp.origin, '''Origin is empty for «tvp.name»''')];
		}

		if(tvp.origin.eClass.EReferences.contains(tvp.reference) && tvp.origin.eIsSet(tvp.reference)) {
			return #[TypeVariableAdapter.get(tvp.origin.eGet(tvp.reference) as EObject)];
		}

		val scope = scopeProvider.getScope(tvp.origin, tvp.reference);
		val scopeElements = scope.getElements(tvp.targetQID);
		val cachedTypeSerializations = scopeElements.map[getUserData("TypeVariable")];
		if(!cachedTypeSerializations.empty && cachedTypeSerializations.forall[it !== null]) {
			val cachedTypes = cachedTypeSerializations.map[serializationAdapter.deserializeTypeFromJSON(it, [ resource.resourceSet.getEObject(it, false) ])]
			// these proxies should not be ambiguous, otherwise we should have created a type class!
			return cachedTypes.map[typ | typ.replaceProxies[ this.resolveProxy(it, resource, scopeProvider).head ]];
		}
		
		val replacementObjects = scopeElements.map[EObjectOrProxy].force;
		if(replacementObjects.empty) {
			scopeProvider.getScope(tvp.origin, tvp.reference);
			return #[new BottomType(tvp.origin, '''Scope doesn't contain «tvp.targetQID» for «tvp.reference.EContainingClass.name».«tvp.reference.name» on «tvp.origin»''')];
		}
		if(tvp.origin.eClass.EReferences.contains(tvp.reference) && !tvp.origin.eIsSet(tvp.reference) && replacementObjects.size == 1) {
			val cacheAdapters = resource.eAdapters.filter(OnChangeEvictingCache.CacheAdapter).force;
			cacheAdapters.forEach[
				it.ignoreNotifications();
			]
			tvp.origin.eSet(tvp.reference, replacementObjects.head);
			cacheAdapters.forEach[
				it.listenToNotifications();
			]
		}
		
		return replacementObjects.map[TypeVariableAdapter.get(it) as AbstractType].force;
	}
	
}
