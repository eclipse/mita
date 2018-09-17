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
	
	// name of the origin member we want to resolve
	protected final String reference;
	
	// name of a specific element we aim to resolve
	protected final QualifiedName targetQID;
	
	new(EObject origin, EReference reference) {
		super(origin, '''p_«instanceCount++»''')
		this.reference = reference.name;
		this.targetQID = QualifiedName.create(NodeModelUtils.findNodesForFeature(origin, reference)?.head?.text?.trim?.split("\\."));
	}
	
	new(EObject origin, EReference reference, QualifiedName targetQID) {
		super(origin, '''p_«instanceCount++»''')
		this.reference = reference.name;
		this.targetQID = targetQID;
	}
	
	new(EObject origin, String name, String reference, QualifiedName targetQID) {
		super(origin, name)
		this.reference = reference;
		this.targetQID = targetQID;
	}
	
	override replaceProxies(IScopeProvider scopeProvider) {
		val scope = scopeProvider.getScope(origin, getEReference);
		return TypeVariableAdapter.get(scope.getSingleElement(targetQID).EObjectOrProxy);
	}
	
	protected def EReference getEReference() {
		val ref = origin?.eClass.EAllReferences.findFirst[ it.name == reference ];
		if(ref === null) {
			throw new IllegalStateException('''Cannot find reference «reference» on «origin?.eClass»''');
		}
		return ref;
	}
	
}