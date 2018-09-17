package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
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
	protected final EReference reference;
	protected final QualifiedName qualifiedName;
	
	new(EObject origin, EReference reference) {
		super(origin, '''p_«instanceCount++»''')
		this.reference = reference;
		this.qualifiedName = QualifiedName.create(NodeModelUtils.findNodesForFeature(origin, reference)?.head?.text?.trim?.split("\\.") ?: (#[] as String[]));
	}
	
	override replaceProxies(IScopeProvider scopeProvider) {
		val scope = scopeProvider.getScope(origin, reference);
		TypeVariableAdapter.get(scope.getSingleElement(qualifiedName).EObjectOrProxy);
	}
}