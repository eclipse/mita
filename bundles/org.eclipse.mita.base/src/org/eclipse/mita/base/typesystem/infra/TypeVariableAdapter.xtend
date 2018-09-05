package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor
@Accessors
class TypeVariableAdapter extends AdapterImpl {
	protected final TypeVariable representedBy;
	
	public static def TypeVariable get(EObject obj) {
		var candidate = obj.eAdapters.filter(TypeVariableAdapter).map[ it.representedBy ].head;
		if(candidate === null) {
			candidate = new TypeVariable(obj);
			obj.eAdapters.add(new TypeVariableAdapter(candidate));
		}
		return candidate;
	}
	
}