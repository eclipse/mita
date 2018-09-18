package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy

/**
 * Base types are types without type variables (e.g. atomic types or integers)
 */
abstract class AbstractBaseType extends AbstractType {
	
	new(EObject origin, String name) {
		super(origin, name)
	}
	override toGraphviz() {
		return "";
	}
	
	override replaceProxies((TypeVariableProxy) => AbstractType resolve) {
		return this;
	}	
}