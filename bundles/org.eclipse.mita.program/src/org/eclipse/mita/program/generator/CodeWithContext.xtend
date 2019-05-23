package org.eclipse.mita.program.generator

import com.google.common.base.Optional
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult
import org.eclipse.xtend.lib.annotations.Accessors

import static extension org.eclipse.mita.base.types.TypesUtil.ignoreCoercions

@Accessors
class CodeWithContext {
	protected val AbstractType type;
	protected val Optional<EObject> obj;
	protected val CodeFragment code;
	protected val ValidElementSizeInferenceResult size;
	
	new(AbstractType type, Optional<EObject> obj, CodeFragment code, ValidElementSizeInferenceResult size) {
		this.type = type;
		this.obj = obj.transform([ignoreCoercions]);
		this.code = code;
		this.size = size;
	}
	
}