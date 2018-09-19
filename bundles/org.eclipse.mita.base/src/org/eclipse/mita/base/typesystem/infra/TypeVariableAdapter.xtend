package org.eclipse.mita.base.typesystem.infra

import java.util.HashMap
import java.util.Map
import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.naming.QualifiedName

@Accessors
class TypeVariableAdapter extends AdapterImpl {
	protected final Map<Object, TypeVariable> variables = new HashMap;
	
	public static def TypeVariable get(EObject obj) {
		getOrCreate(obj, obj, [ new TypeVariable(it) ]);
	}
	
	public static def TypeVariable getProxy(EObject obj, EReference reference) {
		getOrCreate(obj, obj -> reference, [ new TypeVariableProxy(it, reference) ]);
	}
	
	public static def TypeVariable getProxy(EObject obj, EReference reference, QualifiedName objName) {
		getOrCreate(obj, obj -> reference -> objName, [ new TypeVariableProxy(it, reference, objName) ]);
	}
	
	protected static def getOrCreate(EObject obj, Object key, (EObject) => TypeVariable factory) {
		val adapter = obj.eAdapters.filter(TypeVariableAdapter).head ?: new TypeVariableAdapter() => [obj.eAdapters.add(it)];
		val candidate = adapter.variables.computeIfAbsent(key, [ __ |
			factory.apply(obj) => [adapter.variables.put(key, it)];
		])
		return candidate;
	}
	
	/**
	 * Disassociates an object from a type variable. 
	 * 
	 * @return true if any "clearing" happened
	 */
	public static def clear(EObject obj) {
		return obj.eAdapters.removeIf([ it instanceof TypeVariableAdapter]);
	}
	
}