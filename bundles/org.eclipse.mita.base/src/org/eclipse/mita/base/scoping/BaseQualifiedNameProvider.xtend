package org.eclipse.mita.base.scoping

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.Parameter
import org.eclipse.mita.base.types.TypeKind
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.types.VirtualFunction
import org.eclipse.xtext.naming.DefaultDeclarativeQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName

class BaseQualifiedNameProvider extends DefaultDeclarativeQualifiedNameProvider {
	dispatch def QualifiedName doGetFullyQualifiedName(TypeSpecifier ele) {
		val outerQualifiedName = ele.eContainer?.fullyQualifiedName ?: QualifiedName.EMPTY
		return outerQualifiedName.append("0TypeSpecifier");
	}
	override getFullyQualifiedName(EObject obj) {
		return doGetFullyQualifiedName(obj)
	}
	dispatch def QualifiedName doGetFullyQualifiedName(VirtualFunction f) {
		return getFullyQualifiedName(f.eContainer);
	}
	
	dispatch def QualifiedName doGetFullyQualifiedName(Parameter p) {
		val parent = p.eContainer;
		val parentQID = parent.fullyQualifiedName;
		if(parentQID === null) {
			return QualifiedName.create(p.name);
		}
		return parentQID.append(p.name);
		
	}
		
	protected dispatch def QualifiedName doGetFullyQualifiedName(TypeKind t) {
		//return getFullyQualifiedName(t.eContainer.eContainer).append(QualifiedName.create(#["_kinds", t.name]));
		return getFullyQualifiedName(t.eContainer.eContainer).append(t.name);
	}
	
	protected dispatch def QualifiedName doGetFullyQualifiedName(EObject obj) {
		return super.getFullyQualifiedName(obj);
	}
}