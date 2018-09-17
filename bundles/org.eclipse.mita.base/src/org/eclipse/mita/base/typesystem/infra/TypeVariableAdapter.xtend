package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.emf.ecore.EReference

@FinalFieldsConstructor
@Accessors
class TypeVariableAdapter extends AdapterImpl {
	protected final TypeVariable representedBy;
	
	public static def TypeVariable get(EObject obj) {
		getOrCreate(obj, [ new TypeVariable(it) ]);
	}
	
	public static def TypeVariable getProxy(EObject obj, EReference reference) {
		getOrCreate(obj, [ new TypeVariableProxy(it, reference.name) ]);
	}
	
	protected static def getOrCreate(EObject obj, (EObject) => TypeVariable factory) {
		var candidate = obj.eAdapters.filter(TypeVariableAdapter).map[ it.representedBy ].head;
		if(candidate === null) {
			candidate = factory.apply(obj);
			obj.eAdapters.add(new TypeVariableAdapter(candidate));
		}
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