package org.eclipse.mita.base.typesystem.infra

import java.util.HashMap
import java.util.Map
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

import static extension org.eclipse.mita.base.util.BaseUtils.force
import org.eclipse.emf.ecore.impl.EObjectImpl
import java.util.Collections

@Accessors
class TypeClass {
	val Map<AbstractType, EObject> instances;
	val AbstractType mostSpecificGeneralization;
	
	new() {
		this(new HashMap());
	}
	new(Map<AbstractType, EObject> instances) {
		this(instances, null);
	}
	new(Map<AbstractType, EObject> instances, AbstractType mostSpecificGeneralization) {
		this.instances = new HashMap(instances);
		this.mostSpecificGeneralization = mostSpecificGeneralization;
		if(this.toString.contains("f_1719.6 = x_axis: int32")) {
			print("");
		}
	}
	new(Iterable<Pair<AbstractType, EObject>> instances) {
		this();
		instances.forEach[this.instances.put(it.key, it.value)];
		if(this.toString.contains("f_1719.6 = x_axis: int32")) {
			print("");
		}
	}
	
	override toString() {
		return '''
		«instances.values.filter(NamedElement).head?.name»
			«FOR t_o: instances.entrySet.sortBy[it.key.toString]»
			«t_o.key» = «t_o.value»
			«ENDFOR»
		'''; 
	}
	
	def replace(TypeVariable from, AbstractType with) {
		return new TypeClass(instances.entrySet.toMap([it.key.replace(from, with)], [it.value]), mostSpecificGeneralization);
	}
	
	def replace(Substitution sub) {
		return new TypeClass(instances.entrySet.toMap([it.key.replace(sub)], [it.value]), mostSpecificGeneralization)
	}
	def replaceProxies((TypeVariableProxy) => Iterable<AbstractType> typeVariableResolver, (URI) => EObject objectResolver) {
		return this;
	}
	
	def TypeClass modifyNames(String suffix) {
		return new TypeClass(instances.entrySet.toMap([it.key.modifyNames(suffix)], [it.value]), mostSpecificGeneralization)
	}
}

@Accessors
class TypeClassProxy extends TypeClass {
	val TypeVariableProxy toResolve;
	
	new(TypeVariableProxy toResolve) {
		super(Collections.EMPTY_MAP);
		this.toResolve = toResolve;
		if(this.toString.contains("p_4")) {
			print("");
		}
	}
	
	override replace(Substitution sub) {
		return this;
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return this;
	}
	
	override TypeClass modifyNames(String suffix) {
		return new TypeClassProxy(toResolve.modifyNames(suffix) as TypeVariableProxy);
	}
	
	override replaceProxies((TypeVariableProxy) => Iterable<AbstractType> typeVariableResolver, (URI) => EObject objectResolver) {
		val elements = typeVariableResolver.apply(toResolve).toList;
		return new TypeClass(elements.map[tv |
			val origin = tv.origin; 
			tv -> if(origin?.eIsProxy) { 
				objectResolver.apply((origin as EObjectImpl).eProxyURI);
			} else {
				origin
			}
		].force);
	}
	
	override String toString() {
		return '''TCP: «toResolve»'''
	}
}
