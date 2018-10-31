package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.ArrayList
import java.util.Collections
import java.util.HashMap
import java.util.HashSet
import java.util.List
import java.util.Map
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.emf.ecore.InternalEObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.infra.Graph
import org.eclipse.mita.base.typesystem.infra.TypeClass
import org.eclipse.mita.base.typesystem.infra.TypeClassProxy
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.serialization.SerializationAdapter
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.xtext.util.OnChangeEvictingCache

import static extension org.eclipse.mita.base.util.BaseUtils.force

@Accessors
class ConstraintSystem {
	@Inject protected Provider<ConstraintSystem> constraintSystemProvider; 
	@Inject protected SerializationAdapter serializationAdapter;
	protected List<AbstractTypeConstraint> constraints = new ArrayList;
	protected Map<URI, TypeVariable> symbolTable = new HashMap();
	protected Map<QualifiedName, TypeClass> typeClasses = new HashMap();

	// not use atm - is not passed through/serialized in the index
	protected Graph<AbstractType> explicitSubtypeRelations;
	
	var int instanceCount = 0;
		
	def TypeVariable newTypeVariable(EObject obj) {
		new TypeVariable(obj, '''f_«instanceCount++»''')
	}
	
	def TypeVariableProxy newTypeVariableProxy(EObject origin, EReference reference) {
		return new TypeVariableProxy(origin, '''p_«instanceCount++»''', reference);
	}
	
	def TypeVariableProxy newTypeVariableProxy(EObject origin, EReference reference, QualifiedName qualifiedName) {
		return new TypeVariableProxy(origin, '''p_«instanceCount++»''', reference, qualifiedName);
	}
	
	
	def TypeVariable getTypeVariable(EObject obj) {
		val uri = EcoreUtil.getURI(obj);

		getOrCreate(obj, uri, [ 
			newTypeVariable(it)
		]);
	}
	
	def TypeVariable getTypeVariableProxy(EObject obj, EReference reference) {
		val ieobject = obj as InternalEObject;
		val container = ieobject.eInternalContainer();
		val baseUri = EcoreUtil.getURI(obj);
		val uriFragment = container.eURIFragmentSegment(reference, ieobject);
		val uri = obj.eResource.getURI().appendFragment( baseUri + "/" + uriFragment);
		getOrCreate(obj, uri, [ 
			new TypeVariableProxy(it, '''p_«instanceCount++»''', reference)
		]);
	}
	
	def TypeVariable getTypeVariableProxy(EObject obj, EReference reference, QualifiedName objName) {
		val ieobject = obj as InternalEObject;
		val container = ieobject.eInternalContainer();
		val baseUri = EcoreUtil.getURI(obj);
		val uriFragment = container.eURIFragmentSegment(reference, ieobject);
		val uri = obj.eResource.getURI().appendFragment( baseUri + "/" + uriFragment).appendQuery(objName.toString);
		getOrCreate(obj, uri, [ 
			new TypeVariableProxy(it, '''p_«instanceCount++»''', reference, objName)
		]);
	}
	
	def ConstraintSystem modifyNames(String suffix) {
		val result = constraintSystemProvider.get();
		result.constraintSystemProvider = result.constraintSystemProvider ?: constraintSystemProvider;
		result.instanceCount = instanceCount;
		result.constraints += constraints.map[it.modifyNames(suffix)]
		result.symbolTable.putAll(symbolTable.mapValues[it.modifyNames(suffix) as TypeVariable])
		result.typeClasses.putAll(typeClasses.mapValues[it.modifyNames(suffix)]);
		return result;
	}
	
	protected def getOrCreate(EObject obj, URI uri, (EObject) => TypeVariable factory) {
		
		val candidate = symbolTable.computeIfAbsent(uri, [ __ |
			factory.apply(obj);
		])
		return candidate;
	}
	
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
		
		return '''
		Type Classes:
			«FOR tc: typeClasses.entrySet»
			«tc»
			«ENDFOR»
			
		Constraints:
			«FOR c: constraints»
			«c»
			«ENDFOR»
		'''
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
		
		result.instanceCount = instanceCount;
		result.symbolTable.putAll(symbolTable)
		result.constraintSystemProvider = constraintSystemProvider;
		result.explicitSubtypeRelations = explicitSubtypeRelations;
		result.typeClasses = typeClasses;
	
		if(constraints.empty) {
			return (null -> result);
		}
	
		result.constraints = constraints.tail.force;
		return constraints.head -> result;
	}
	
	def takeOneNonAtomic() {
		val result = constraintSystemProvider?.get() ?: new ConstraintSystem();
		result.instanceCount = instanceCount;
		result.symbolTable.putAll(symbolTable)
		result.constraintSystemProvider = constraintSystemProvider;
		result.explicitSubtypeRelations = explicitSubtypeRelations;
		result.typeClasses = typeClasses;

		val atomics = constraints.filter[constraintIsAtomic];
		val nonAtomics = constraints.filter[!constraintIsAtomic];

		if(nonAtomics.empty) {
			result.constraints = atomics.force;
			return (null -> result);
		}
		
		result.constraints = (nonAtomics.tail + atomics).force;
		return nonAtomics.head -> result;
	}
	
	def hasNonAtomicConstraints() {
		return this.constraints.exists[!constraintIsAtomic];
	}
	
	def constraintIsAtomic(AbstractTypeConstraint c) {
		return c.isAtomic;
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
			r.instanceCount += t.instanceCount;
			r.symbolTable.putAll(t.symbolTable);
			r.constraints.addAll(t.constraints);
			r.typeClasses.putAll(t.typeClasses);
			t.explicitSubtypeRelations => [g | g.nodes.forEach[typeNode | 
				g.reverseMap.get(typeNode).forEach[typeIdx |
					g.getPredecessors(typeIdx).forEach[r.explicitSubtypeRelations.addEdge(it, typeNode)]
					g.getSuccessors(typeIdx).forEach[r.explicitSubtypeRelations.addEdge(typeNode, it)]
				]
			]]
			return r;
		]);
		result.constraintSystemProvider = csp;
		return result;
	}
	
	def replace(Substitution substitution) {
		val newConstraints = new ArrayList();
		newConstraints.addAll(constraints.map[ it.replace(substitution) ]);
		this.constraints = newConstraints;
		return this;
	}
	
	def ConstraintSystem replaceProxies(Resource resource, IScopeProvider scopeProvider) {
		val result = constraintSystemProvider.get();
		result.instanceCount = instanceCount;
		result.symbolTable.putAll(symbolTable);

		result.constraints += constraints.map[ it.replaceProxies[ 
			this.resolveProxy(it, resource, scopeProvider).head
		] ].force;
		result.typeClasses.putAll(typeClasses.mapValues[ 
			it.replaceProxies([ 
				this.resolveProxy(it, resource, scopeProvider)
			], [
				resource.resourceSet.getEObject(it, false)
			])
		]);
		
		result.explicitSubtypeRelations = explicitSubtypeRelations.clone() as Graph<AbstractType>;
		return result;
	}
	
	protected def Iterable<AbstractType> resolveProxy(TypeVariableProxy tvp, Resource resource, IScopeProvider scopeProvider) {
		if(tvp.origin === null) {
			return #[new BottomType(tvp.origin, '''Origin is empty for «tvp.name»''')];
		}

		if(tvp.origin.eClass.EReferences.contains(tvp.reference) && tvp.origin.eIsSet(tvp.reference)) {
			return #[getTypeVariable(tvp.origin.eGet(tvp.reference) as EObject)];
		}

		val scope = scopeProvider.getScope(tvp.origin, tvp.reference);
		val scopeElements = scope.getElements(tvp.targetQID).toList;
		val cachedTypeSerializations = scopeElements.map[getUserData("TypeVariable")].toList;
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
			BaseUtils.ignoreChange(resource, [ 
				tvp.origin.eSet(tvp.reference, replacementObjects.head);
			]);
		}
		
		return replacementObjects.map[
			this.getTypeVariable(it) as AbstractType
		].force;
	}
	
}
