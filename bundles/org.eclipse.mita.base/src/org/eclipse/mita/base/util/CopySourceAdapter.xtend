package org.eclipse.mita.base.util

import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.emf.ecore.EObject

class CopySourceAdapter extends AdapterImpl {
	val EObject origin;
	
	new(EObject origin) {
		this.origin = origin;
	}
	
	def getOrigin() {
		origin;
	}
}