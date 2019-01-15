package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.util.NodeModelUtils

@EqualsHashCode
@Accessors
@FinalFieldsConstructor
class TypeVariableProxy extends TypeVariable {
	protected final EReference reference;
	// name of the origin member we want to resolve
	protected final QualifiedName targetQID;	
	protected final boolean isLinkingProxy;
	protected AmbiguityResolutionStrategy ambiguityResolutionStrategy = AmbiguityResolutionStrategy.UseFirst;
	
	enum AmbiguityResolutionStrategy {
		UseFirst, UseLast, MakeNew;
	}
	
	new(EObject origin, String name, EReference reference, QualifiedName targetQID, AmbiguityResolutionStrategy ambiguityResolutionStrategy) {
		this(origin, name, reference, targetQID);
		this.ambiguityResolutionStrategy = ambiguityResolutionStrategy;
	}
	
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
	}
	
	override replaceProxies(ConstraintSystem system, (TypeVariableProxy) => Iterable<AbstractType> resolve) {
		val candidates = resolve.apply(this);
		return if(candidates.size === 1) {
			candidates.head;
		}
		else {
			switch ambiguityResolutionStrategy {
				case UseFirst: candidates.head
				case UseLast: candidates.last
				case MakeNew: system.newTypeVariable(null)
			}
		}
	}
	
	override map((AbstractType)=>AbstractType f) {
		return f.apply(this);
	}
	
	override modifyNames(String suffix) {
		return new TypeVariableProxy(origin, name + suffix, reference, targetQID) => [
			it.ambiguityResolutionStrategy = this.ambiguityResolutionStrategy;
		];
	}
	
}