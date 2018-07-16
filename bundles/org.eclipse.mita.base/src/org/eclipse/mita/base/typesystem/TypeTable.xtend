package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import java.util.Collections
import java.util.HashMap
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName

class TypeTable {
	
	protected Map<QualifiedName, AbstractType> content = new HashMap;
	
	@Inject
	protected IQualifiedNameProvider nameProvider;
	
	def put(EObject obj, AbstractType type) {
		content.put(nameProvider.getFullyQualifiedName(obj), type);
	}
	
	public def getContent() {
		return Collections.unmodifiableMap(this.content);
	}
	
	public def get(EObject obj) {
		return content.get(nameProvider.getFullyQualifiedName(obj));
	}
		
}