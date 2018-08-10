package org.eclipse.mita.base.util

import com.google.common.base.Optional
import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.emf.ecore.EObject

class PreventRecursionAdapter extends AdapterImpl {
	static def <T> Optional<T> preventRecursion(EObject obj, () => T action) {
		preventRecursion(obj, [| Optional.fromNullable(action.apply)], [| return Optional.absent]);
	}
	static def <T> T preventRecursion(EObject obj, () => T action, () => T onRecursion) {
		if(PreventRecursionAdapter.isMarked(obj)) {
			return onRecursion.apply();
		}
		val adapter = PreventRecursionAdapter.applyTo(obj);
		try {
			return action.apply();	
		}
		finally {
			adapter.removeFrom(obj);
		}
	}
	static def boolean isMarked(EObject obj) {
		return obj.eAdapters.exists[it instanceof PreventRecursionAdapter];
	}
	
	static def PreventRecursionAdapter applyTo(EObject target) {
		val adapter = new PreventRecursionAdapter();
		target.eAdapters.add(adapter);
		return adapter;
	}
	
	static def removeFromBySearch(EObject target) {
		target.eAdapters.removeIf[it instanceof PreventRecursionAdapter];
	}
	
	def removeFrom(EObject target) {
		target.eAdapters.remove(this);
	}
}