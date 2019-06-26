package org.eclipse.mita.program.generator

import java.util.Optional
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtend.lib.annotations.Accessors

import static extension org.eclipse.mita.base.types.TypeUtils.ignoreCoercions

@Accessors
class CodeWithContext {
	protected val AbstractType type;
	protected val Optional<EObject> obj;
	protected val CodeFragment code;
	
	new(AbstractType type, Optional<EObject> obj, CodeFragment code) {
		this.type = type;
		this.obj = obj.map([ignoreCoercions]);
		this.code = code;
	}
	
}