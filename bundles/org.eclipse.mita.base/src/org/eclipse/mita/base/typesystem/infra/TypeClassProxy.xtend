package org.eclipse.mita.base.typesystem.infra

import java.util.Collections
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.impl.EObjectImpl
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors

import static extension org.eclipse.mita.base.util.BaseUtils.force

@Accessors
class TypeClassProxy extends TypeClass {
	val TypeVariableProxy toResolve;
	
	new(TypeVariableProxy toResolve) {
		super(Collections.EMPTY_MAP);
		this.toResolve = toResolve;
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