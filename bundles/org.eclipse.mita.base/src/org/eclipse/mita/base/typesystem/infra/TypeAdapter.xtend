package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor
class TypeAdapter extends AdapterImpl {
	protected final AbstractType type;
	
	static def void set(EObject obj, AbstractType type) {
		obj.eAdapters.add(new TypeAdapter(type));
	}
	
	static def AbstractType get(EObject obj) {
		return obj?.eAdapters?.filter(TypeAdapter)?.head?.type;
	}
	
	public override toString() {
		return '''TypeAdapter: «type»''';
	}
	
}