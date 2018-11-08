package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem

@Accessors
class TypeTranslationAdapter extends AdapterImpl {
	protected AbstractType typeTranslation;
	new(AbstractType translation) {
		this.typeTranslation = translation;
	}
	
	static def AbstractType get(ConstraintSystem s, EObject obj, (EObject) => AbstractType calculateType) {
		return get(s, obj, [|calculateType.apply(obj)]);
	}
	static def AbstractType get(ConstraintSystem s, EObject obj, () => AbstractType calculateType) {
		var candidate = s.typeTranslations.get(obj);
		if(candidate === null) {
			candidate = calculateType.apply;
			val alreadySet = s.typeTranslations.get(obj);
			if(alreadySet !== null) {
				println("Overwriting: " + alreadySet + " | with: " + candidate);
			}
			s.typeTranslations.put(obj, candidate);
		}
		return candidate;
	}
	
	static def AbstractType set(ConstraintSystem s, EObject obj, AbstractType translation) {
		s.typeTranslations.put(obj, translation);
		return translation;
	}
	
}