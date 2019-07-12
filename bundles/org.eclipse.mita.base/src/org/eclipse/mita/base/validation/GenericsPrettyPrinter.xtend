/** 
 * Copyright (c) 2015 committers of YAKINDU and others. 
 * All rights reserved. This program and the accompanying materials 
 * are made available under the terms of the Eclipse Public License v1.0 
 * which accompanies this distribution, and is available at 
 * http://www.eclipse.org/legal/epl-v10.html 
 * Contributors:
 * committers of YAKINDU - initial API and implementation
 *
*/
package org.eclipse.mita.base.validation

import java.util.List
import org.eclipse.mita.base.types.InstanceTypeParameter
import org.eclipse.mita.base.types.Type
import org.eclipse.mita.base.types.TypeParameter
import org.eclipse.mita.base.types.TypeReferenceSpecifier
import org.eclipse.mita.base.types.TypeSpecifier

class GenericsPrettyPrinter {

	def concatTypeParameter(List<TypeParameter> parameter) {
		return '''<«FOR param : parameter SEPARATOR ', '»«param.name»«IF param instanceof InstanceTypeParameter» is «(param.ofType as Type).name»«ENDIF»«ENDFOR»>'''.toString
	}

	def <T extends TypeSpecifier> concatTypeArguments(List<T> parameter) {
		// TODO: type arguments can have multiple hierarches Type1<Type2<T>>
		return '''<«FOR param : parameter.filter(TypeReferenceSpecifier) SEPARATOR ', '»«param.type.name»«ENDFOR»>'''.toString
	}
}
