package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@EqualsHashCode
@Accessors
@FinalFieldsConstructor
class TypeVariableProxy extends TypeVariable {
	protected final EReference reference;
	// name of the origin member we want to resolve
	protected final QualifiedName targetQID;	
	protected final boolean isLinkingProxy;
	
	new(EObject origin, String name, EReference reference) {
		this(origin, name, reference, QualifiedName.create((
				(if(origin.eGet(reference) !== null) {
					val obj = origin.eGet(reference);
					if(obj instanceof NamedElement) {
						obj.name;
					}
				}) ?: NodeModelUtils.findNodesForFeature(origin, reference)?.head?.text?.trim
			)?.split("\\.")), true);
	}
	
	new(EObject origin, String name, EReference reference, QualifiedName qualifiedName) {
		this(origin, name, reference, qualifiedName, false);
		if(qualifiedName.toString.trim == "∗foo") {
			print("");
		}
	}
	
	override replaceProxies((TypeVariableProxy) => AbstractType resolve) {
		if(this.toString.startsWith("p_244")) {
			print("");
		}
		return resolve.apply(this);
	}
	
	override map((AbstractType)=>AbstractType f) {
		return f.apply(this);
	}
	
	override modifyNames(String suffix) {
		return new TypeVariableProxy(origin, name + suffix, reference, targetQID);
	}
	
}