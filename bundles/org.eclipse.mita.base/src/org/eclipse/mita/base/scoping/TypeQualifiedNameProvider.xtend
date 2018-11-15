package org.eclipse.mita.base.scoping

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.TypeKind
import org.eclipse.mita.base.types.VirtualFunction
import org.eclipse.xtext.naming.DefaultDeclarativeQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName

class TypeQualifiedNameProvider extends BaseQualifiedNameProvider {
	
	override getFullyQualifiedName(EObject obj) {
		return doGetFullyQualifiedName(obj)
	}
	
	protected dispatch def QualifiedName doGetFullyQualifiedName(SumAlternative s) {
		val parentQN = s.eContainer.eContainer.fullyQualifiedName;
		val thisQN = QualifiedName.create(s.name);
		if(parentQN !== null) {
			return parentQN.append(thisQN);
		}
		return thisQN;
	}
	
	protected dispatch def QualifiedName doGetFullyQualifiedName(VirtualFunction f) {
		return getFullyQualifiedName(f.eContainer);
	}
	
	protected dispatch def QualifiedName doGetFullyQualifiedName(TypeKind t) {
		//return getFullyQualifiedName(t.eContainer.eContainer).append(QualifiedName.create(#["_kinds", t.name]));
		return getFullyQualifiedName(t.eContainer.eContainer).append(t.name);
	}
	
	protected dispatch def QualifiedName doGetFullyQualifiedName(EObject obj) {
		return super.getFullyQualifiedName(obj);
	}
}