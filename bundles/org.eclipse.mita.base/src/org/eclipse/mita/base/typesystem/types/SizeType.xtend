package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class SizeType extends AbstractBaseType {
	val long size;
	
	new(EObject origin, long size) {
		super(origin, "size_" + size)
		this.size = size;
	}
	
	override getFreeVars() {
		return #[];
	}
	
}