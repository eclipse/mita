package org.eclipse.mita.base.scoping

import org.eclipse.xtext.scoping.impl.ImportNormalizer
import org.eclipse.xtext.naming.QualifiedName

class TypeKindNormalizer extends ImportNormalizer {
	
	new(QualifiedName importedNamespace, boolean wildCard, boolean ignoreCase) {
		super(importedNamespace, wildCard, ignoreCase)
	}
	
	new() {
		super(QualifiedName.create("∗"), true, false);
	}
	
	override deresolve(QualifiedName fullyQualifiedName) {
		if(fullyQualifiedName.firstSegment.startsWith("∗")) {
			return QualifiedName.create(fullyQualifiedName.firstSegment.substring(1)).append(fullyQualifiedName.skipFirst(1));
		}
		return fullyQualifiedName;
	}
	
	override resolve(QualifiedName relativeName) {
		if (relativeName.isEmpty()) {
			return null;
		}
		
		return QualifiedName.create("∗" + relativeName.firstSegment).append(relativeName.skipFirst(1));
		
	}
	
}
