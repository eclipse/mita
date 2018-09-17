package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.scoping.IScopeProvider

@EqualsHashCode
@Accessors
@FinalFieldsConstructor
class TypeVariableProxy extends TypeVariable {
	static Integer instanceCount = 0;
	protected final QualifiedName qualifiedName;
	
	// name of the origin member we want to resolve
	protected final String reference;
	
	new(EObject origin, String reference) {
		super(origin, '''p_«instanceCount++»''')
		this.reference = reference;
		this.qualifiedName = QualifiedName.create(NodeModelUtils.findNodesForFeature(origin, reference)?.head?.text?.trim?.split("\\.") ?: (#[] as String[]));
	}
	
	new(EObject origin, String name, String reference) {
		super(origin, name)
		this.reference = reference;
	}
		
	
	override replaceProxies(IScopeProvider scopeProvider) {
		val scope = scopeProvider.getScope(origin, reference);
		TypeVariableAdapter.get(scope.getSingleElement(qualifiedName).EObjectOrProxy);
	}
}