package org.eclipse.mita.base.generator

import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.naming.DefaultDeclarativeQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName

class BaseQualifiedNameProvider extends DefaultDeclarativeQualifiedNameProvider {
	public override QualifiedName getFullyQualifiedName(EObject obj) {
		val superResult = super.getFullyQualifiedName(obj);
		if(superResult !== null) {
			return superResult;
		}
		
		val container = obj.eContainer;
		if(container === null) {
			return QualifiedName.create("_1");
		}
		return container.fullyQualifiedName.append('''«obj.eClass.name»_«container.eContents.indexOf(obj)»''');
	}
}