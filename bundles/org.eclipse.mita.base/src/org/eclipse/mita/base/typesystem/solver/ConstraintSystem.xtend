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
import java.util.ArrayList
import java.util.HashMap
import java.util.HashSet
import java.util.List
import java.util.Map
import org.eclipse.core.runtime.CoreException
import org.eclipse.core.runtime.IStatus
import org.eclipse.core.runtime.Status
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
import org.eclipse.mita.base.typesystem.serialization.SerializationAdapter
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AbstractType.Either
import org.eclipse.mita.base.typesystem.types.AbstractType.NameModifier
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeHole
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.typesystem.types.TypeVariableProxy
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.scoping.IScopeProvider

import static extension org.eclipse.mita.base.util.BaseUtils.force
import org.eclipse.mita.base.typesystem.types.DependentTypeVariable
import org.eclipse.mita.base.types.InstanceTypeParameter

@Accessors
class ConstraintSystem {
	@Inject protected Provider<ConstraintSystem> constraintSystemProvider; 
	@Inject protected SerializationAdapter serializationAdapter;
	protected Map<URI, TypeVariable> symbolTable = new HashMap();
	protected Map<QualifiedName, AbstractType> typeTable = new HashMap();
	protected Map<QualifiedName, TypeClass> typeClasses = new HashMap();
	protected List<AbstractTypeConstraint> atomicConstraints = new ArrayList();
	protected List<AbstractTypeConstraint> nonAtomicConstraints = new ArrayList();
	protected Graph<AbstractType> explicitSubtypeRelations;
	protected Map<Integer, AbstractType> explicitSubtypeRelationsTypeSource = new HashMap();
	protected Map<String, Map<String, String>> userData = new HashMap();
	protected Map<URI, AbstractType> coercions = new HashMap();
	
	private def Map<String, String> internGetUserData(String key) {
		userData.computeIfAbsent(key, [new HashMap()]);
	}
		
	dispatch def Map<String, String> doGetUserData(TypeConstructorType t) {
		return getUserData(t.typeArguments.head);
	}
	dispatch def Map<String, String> doGetUserData(TypeVariable t) {
		return internGetUserData(t.toString);
	}
	dispatch def Map<String, String> doGetUserData(AbstractType t) {
		return internGetUserData(t.name);
	}
	def getUserData(AbstractType t) {
		return t?.doGetUserData;
	}
	def getUserData(AbstractType t, String key) {
		return t?.doGetUserData?.get(key);
	}
	
	def void putUserData(AbstractType typeKey, String key, String value) {
		getUserData(typeKey)?.put(key, value);
	}
	
	def getConstraints() {
		return atomicConstraints + nonAtomicConstraints;
	}
	
	var int instanceCount = 0;
		
	def TypeVariable newTypeVariable(EObject obj) {
		new TypeVariable(obj, instanceCount++)
	}
	
	def TypeVariable newTypeHole(EObject obj) {
		new TypeHole(obj, instanceCount++)
	}
	
	def DependentTypeVariable newDependentTypeVariable(InstanceTypeParameter obj, AbstractType dependsOn) {
		return new DependentTypeVariable(obj, instanceCount++, dependsOn);
	}
	
	def TypeVariableProxy newTypeVariableProxy(EObject origin, EReference reference) {
		return new TypeVariableProxy(origin, instanceCount++, reference);
	}
	
	def TypeVariableProxy newTypeVariableProxy(EObject origin, EReference reference, QualifiedName qualifiedName) {
		return new TypeVariableProxy(origin, instanceCount++, reference, qualifiedName);
	}
	
	
	def TypeVariable getTypeVariable(EObject obj, String subfeature) {
		val baseUri = EcoreUtil.getURI(obj);
		val subUri = baseUri.appendFragment(baseUri.fragment + "." + subfeature)
		return getOrCreate(obj, subUri, [
			newTypeVariable(it)
		])
	}
	
	def TypeVariable getTypeVariable(EObject obj) {
		val uri = EcoreUtil.getURI(obj);

		getOrCreate(obj, uri, [ 
			newTypeVariable(it)
		]);
	}
	
	def TypeVariable getTypeVariableProxy(EObject obj, EReference reference) {
		return getTypeVariableProxy(obj, reference, null);
	}
	def TypeVariable getTypeVariableProxy(EObject obj, EReference reference, boolean isLinking) {
		return getTypeVariableProxy(obj, reference, null, isLinking);
	}
	
	def TypeVariable getTypeVariableProxy(EObject obj, EReference reference, QualifiedName objName) {
		return getTypeVariableProxy(obj, reference, objName, true);
	}
	
	def TypeVariable getTypeVariableProxy(EObject obj, EReference reference, QualifiedName objName, boolean isLinking) {
		val ieobject = obj as InternalEObject;
		val container = ieobject.eInternalContainer();
		val baseUri = EcoreUtil.getURI(obj);
		val uriFragment = container.eURIFragmentSegment(reference, ieobject);
		val baseUri2 = obj.eResource.getURI().appendFragment( baseUri + "/" + uriFragment);
		val objNameStr = objName?.toString;
		val uri = if(objNameStr !== null) {
			baseUri2.appendQuery(objName.toString);	
		}
		else {
			baseUri2;
		}
		getOrCreate(obj, uri, [ 
			if(objName !== null) {
				return new TypeVariableProxy(it, instanceCount++, reference, objName, isLinking)
			}
			return new TypeVariableProxy(it, instanceCount++, reference, TypeVariableProxy.getQName(it, reference), isLinking);
		]);
	}
	
	new(ConstraintSystem other) {
		this();
		constraintSystemProvider = constraintSystemProvider ?: other.constraintSystemProvider;
		instanceCount = other.instanceCount;
		atomicConstraints.addAll(other.atomicConstraints);
		nonAtomicConstraints.addAll(other.nonAtomicConstraints);
		symbolTable.putAll(other.symbolTable);
		typeTable.putAll(other.typeTable);
		typeClasses.putAll(other.typeClasses);
		userData.putAll(other.userData.entrySet.toMap([it.key], [new HashMap(it.value)]));
		other.explicitSubtypeRelations.copyTo(explicitSubtypeRelations);
		explicitSubtypeRelationsTypeSource = new HashMap(other.explicitSubtypeRelationsTypeSource);
		coercions.putAll(other.coercions);
	}
		
	def ConstraintSystem modifyNames(int offset) {
		val result = new ConstraintSystem(this);
		val converter = new NameModifier() {
			override apply(int var1) {
				return Either.left(var1+offset);
			}	
		}
		result.atomicConstraints.replaceAll([it.modifyNames(converter)])
		result.nonAtomicConstraints.replaceAll([it.modifyNames(converter)])
		result.symbolTable.replaceAll([k, v | v.modifyNames(converter) as TypeVariable]);
		result.typeTable.replaceAll([k, v | v.modifyNames(converter)]);
		result.typeClasses.replaceAll([k, v | v.modifyNames(converter)]);
		result.explicitSubtypeRelations.nodeIndex.replaceAll[k, v | v.modifyNames(converter)];
		result.explicitSubtypeRelations.computeReverseMap();
		result.explicitSubtypeRelationsTypeSource.replaceAll[k, v | v.modifyNames(converter)];
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
		if(constraint.isAtomic(this)) {
			atomicConstraints.add(constraint);
		}
		else {
			nonAtomicConstraints.add(constraint);
		}
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
		var typeClass = typeClasses.get(qn);
		if(!typeClasses.containsKey(qn)) {
			typeClass = new TypeClassProxy(#[]);
			typeClasses.put(qn, typeClass);
		}
		if(typeClass instanceof TypeClassProxy) {
			typeClass.toResolve.add(tvProxy);
			return typeClass;
		}
		else {
			throw new CoreException(new Status(IStatus.ERROR, "org.eclipse.mita.base", "Tried to get typeClassProxy when type class was already resolved"));
		}
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
	
	def takeOneNonAtomic() {
		if(nonAtomicConstraints.empty) {
			return null;
		}
		
		return nonAtomicConstraints.remove(0);
	}
	
	def hasNonAtomicConstraints() {
		return !nonAtomicConstraints.empty;
	}
	
	def constraintIsAtomic(AbstractTypeConstraint c) {
		return c.isAtomic(this);
	}
	
	def plus(AbstractTypeConstraint constraint) {
		this.addConstraint(constraint);
		return this;
	}
	
	def static combine(Iterable<ConstraintSystem> systems) {
		if(systems.empty) {
			return null;
		}
		
		val csp = systems.map[it.constraintSystemProvider].filterNull.head;
		val result = systems.fold(csp?.get() ?: new ConstraintSystem(), [r, t|
			r.instanceCount += t.instanceCount;
			r.symbolTable.entrySet.filter[t.symbolTable.containsKey(it.key)].forEach[
				// this most likely means that a resource is loaded twice or some resource descriptions are duplicated
				println('''duplicate entry: «it.key» -> «it.value»  ||  «t.symbolTable.get(it.key)»''')
//				r.constraints.add(new EqualityConstraint(it.value, t.symbolTable.get(it.key), "CS:267 (merge)"))
			]
			r.symbolTable.putAll(t.symbolTable);
			r.typeTable.putAll(t.typeTable);
			r.atomicConstraints.addAll(t.atomicConstraints);
			r.nonAtomicConstraints.addAll(t.nonAtomicConstraints);
			r.typeClasses.putAll(t.typeClasses);
			val g = t.explicitSubtypeRelations 
			g.nodes.forEach[typeNode | 
				g.reverseMap.get(typeNode).forEach[typeIdx |
					val typeSource = t.explicitSubtypeRelationsTypeSource.get(typeIdx);
					g.getPredecessors(typeIdx).forEach[
						val newIdx = r.explicitSubtypeRelations.addEdge(it, typeNode).value;
						if(typeSource !== null) {
							r.explicitSubtypeRelationsTypeSource.put(newIdx, typeSource);
						}
					]
					g.getSuccessors(typeIdx).forEach[
						val newIdx = r.explicitSubtypeRelations.addEdge(typeNode, it).key;
						if(typeSource !== null) {
							r.explicitSubtypeRelationsTypeSource.put(newIdx, typeSource);
						}
					]
				]
			]
			r.userData.putAll(t.userData.entrySet.toMap([it.key], [new HashMap(it.value)]));
			r.coercions.putAll(t.coercions);
			return r;
		]);
		result.constraintSystemProvider = csp;
		return result;
	}
	
	def replace(Substitution substitution) {
		atomicConstraints = atomicConstraints.map[ it.replace(substitution) ].force;
		nonAtomicConstraints = nonAtomicConstraints.map[ it.replace(substitution) ].force;
		return this;
	}
	
	def ConstraintSystem replaceProxies(Resource resource, IScopeProvider scopeProvider) {
		val result = new ConstraintSystem(this);

		result.atomicConstraints = atomicConstraints.map[ 
			it.replaceProxies(result, [ 
				result.resolveProxy(it, resource, scopeProvider)
			]) ].force;
		result.nonAtomicConstraints = nonAtomicConstraints.map[ 
			it.replaceProxies(result, [ 
				result.resolveProxy(it, resource, scopeProvider)
			]) ].force;
		result.typeClasses = new HashMap(typeClasses.mapValues[ 
			it.replaceProxies([ 
				result.resolveProxy(it, resource, scopeProvider)
			], [
				resource.resourceSet.getEObject(it, true)
			])
		]);
		
		explicitSubtypeRelations.copyTo(result.explicitSubtypeRelations);
		result.explicitSubtypeRelations.nodeIndex.replaceAll[k, v | v.replaceProxies(this, [this.resolveProxy(it, resource, scopeProvider)])];
		result.explicitSubtypeRelations.computeReverseMap();
		result.explicitSubtypeRelationsTypeSource = new HashMap(explicitSubtypeRelationsTypeSource);
		result.explicitSubtypeRelationsTypeSource.replaceAll[k, v | v.replaceProxies(this, [this.resolveProxy(it, resource, scopeProvider)])];
		return result;
	}
	
	protected def Iterable<AbstractType> resolveProxy(TypeVariableProxy tvp, Resource resource, IScopeProvider scopeProvider) {
		if(tvp.origin === null) {
			return #[new BottomType(tvp.origin, '''Origin is empty for «tvp.name»''')];
		}
		if(tvp.isLinkingProxy && tvp.origin.eClass.EReferences.contains(tvp.reference) && tvp.origin.eIsSet(tvp.reference)) {
			return #[BaseUtils.ignoreChange(tvp.origin, [
					getTypeVariable(tvp.origin.eGet(tvp.reference, false) as EObject)
				])];
		}
		var origin = tvp.origin;
		val name = tvp.targetQID;
		if(tvp.reference.name == "type") {
			val typeCandidate = typeTable.get(tvp.targetQID)
			if(typeCandidate !== null) {
				return #[typeCandidate];
			}
			else {
				if(origin.eIsProxy) {
					origin = EcoreUtil.resolve(origin, resource);
				}
			}
		}
		if(origin.eIsProxy) {
			return #[new BottomType(origin, '''Couldn't resolve reference to «tvp.reference.EReferenceType.name» '«tvp.targetQID»'.''', tvp.reference)];
		}
		val scope = scopeProvider.getScope(origin, tvp.reference);
		val scopeElements = scope.getElements(tvp.targetQID);
		
		val replacementObjects = scopeElements.map[EObjectOrProxy].force.toSet;
		if(replacementObjects.empty) { 
			// redo to allow easier debugging
			scopeProvider.getScope(origin, tvp.reference);
			scope.getElements(tvp.targetQID).force;
			return #[new BottomType(origin, '''Couldn't resolve reference to «tvp.reference.EReferenceType.name» '«tvp.targetQID»'.''', tvp.reference)];
		}
				
		return replacementObjects.map[
			val uri = EcoreUtil.getURI(it);
			if(!symbolTable.containsKey(uri)) {
				// this means that there is an object in scope that we have not seen during constraint generation
				println('''introducing «uri»!''');
			}
			// explicitly set the origin to the resolved object, since the symbol table only contains proxies!
			val tvIdx = this.getTypeVariable(it).idx;
			return new TypeVariable(it, tvIdx) as AbstractType;
		].force;
	}
	
}
