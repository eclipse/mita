package org.eclipse.mita.base.scoping

import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.xtext.naming.DefaultDeclarativeQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName

class BaseQualifiedNameProvider extends DefaultDeclarativeQualifiedNameProvider {
	def QualifiedName qualifiedName(TypeSpecifier ele){
		val outerQualifiedName = ele.eContainer?.fullyQualifiedName ?: QualifiedName.EMPTY
		return outerQualifiedName.append("0TypeSpecifier");
	}
}