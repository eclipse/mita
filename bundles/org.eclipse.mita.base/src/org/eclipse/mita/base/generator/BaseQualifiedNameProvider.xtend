package org.eclipse.mita.base.generator

import java.util.ArrayList
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.xtext.naming.DefaultDeclarativeQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.mita.base.types.PackageMember

class BaseQualifiedNameProvider extends DefaultDeclarativeQualifiedNameProvider {
	public override QualifiedName getFullyQualifiedName(EObject obj) {
		val segments = new ArrayList<String>();
		
		for(var o = obj; o !== null; ) {
			val container = o.eContainer;
			val id = EcoreUtil.getID(o);
			val name = if(o instanceof PackageMember) {
				o.name
			}
			val segment = if(id !== null) {
				id
			} else if(name !== null) {
				name
			} else if(container !== null) {
				'''«o.eClass.name»_«container.eContents.indexOf(o)»'''
			} else {
				o.eResource.URI.lastSegment
			}
			segments.add(segment);
			
			o = container;
		}
				
		return QualifiedName.create(segments.reverseView);
	}

}