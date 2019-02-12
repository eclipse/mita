package org.eclipse.mita.base.typesystem.infra

import java.util.Collections
import java.util.List
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.impl.EObjectImpl
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.typesystem.types.TypeVariableProxy
import org.eclipse.xtend.lib.annotations.Accessors

import static extension org.eclipse.mita.base.util.BaseUtils.force

@Accessors
class TypeClassProxy extends TypeClass {
	val List<TypeVariableProxy> toResolve;
	
	new(Iterable<TypeVariableProxy> toResolve) {
		super(Collections.EMPTY_MAP);
		this.toResolve = newArrayList(toResolve);
	}
	
	override replace(Substitution sub) {
		return this;
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return this;
	}
	
	override TypeClass modifyNames((String) => String converter) {
		return new TypeClassProxy(toResolve.map[it.modifyNames(converter) as TypeVariableProxy]);
	}
	
	override replaceProxies((TypeVariableProxy) => Iterable<AbstractType> typeVariableResolver, (URI) => EObject objectResolver) {
		val elements = toResolve.flatMap[typeVariableResolver.apply(it)].toList;
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