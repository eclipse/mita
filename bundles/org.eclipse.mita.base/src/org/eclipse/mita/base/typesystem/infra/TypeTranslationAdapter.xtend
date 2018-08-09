package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor


@Accessors
class TypeTranslationAdapter extends AdapterImpl {
	protected AbstractType typeTranslation;
	new(AbstractType translation) {
		this.typeTranslation = translation;
	}
	
	static def AbstractType get(EObject obj, (EObject) => AbstractType calculateType) {
		return get(obj, [|calculateType.apply(obj)]);
	}
	static def AbstractType get(EObject obj, () => AbstractType calculateType) {
		var candidate = obj.eAdapters.filter(TypeTranslationAdapter).map[ it.typeTranslation ].head;
		if(candidate === null) {
			candidate = calculateType.apply;
			obj.eAdapters.add(new TypeTranslationAdapter(candidate));
		}
		return candidate;
	}
	
	static def AbstractType set(EObject obj, AbstractType translation) {
		var candidate = obj.eAdapters.filter(TypeTranslationAdapter).head;
		if(candidate === null) {
			candidate = new TypeTranslationAdapter(translation)
			obj.eAdapters.add(candidate);
		}
		else {
			candidate.typeTranslation = translation;
		}
		return translation;
	}
	
}