package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.SumType
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.mita.base.util.BaseUtils
import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull;

@EqualsHashCode
@Accessors
class TypeVariableProxy extends TypeVariable {
	protected final EReference reference;
	// name of the origin member we want to resolve
	protected final QualifiedName targetQID;	
	protected final boolean isLinkingProxy;
	protected AmbiguityResolutionStrategy ambiguityResolutionStrategy = AmbiguityResolutionStrategy.UseFirst;
	
	enum AmbiguityResolutionStrategy {
		UseFirst, UseLast, MakeNew;
	}
	
	new(EObject origin, String name, EReference reference, QualifiedName targetQID, boolean isLinkingProxy) {
		super(origin, name);
		this.reference = reference;
		this.targetQID = targetQID;
		this.isLinkingProxy = isLinkingProxy;
		if(targetQID.toString.nullOrEmpty) {
			throw new IllegalArgumentException("targetQID null or empty");
		}
	}
	
	new(EObject origin, String name, EReference reference, QualifiedName targetQID, AmbiguityResolutionStrategy ambiguityResolutionStrategy) {
		this(origin, name, reference, targetQID);
		this.ambiguityResolutionStrategy = ambiguityResolutionStrategy;
	}
	
	new(EObject origin, String name, EReference reference) {
		this(origin, name, reference, TypeVariableProxy.getQName(origin, reference), true);
	}
	
	protected static def getQName(EObject origin, EReference reference) {
		var QualifiedName maybeQname; 
		if(!origin.eIsProxy) {
			val obj = origin.eGet(reference, false);
			if(obj instanceof NamedElement && obj instanceof EObject && !(obj as EObject).eIsProxy) {
				if(obj instanceof SumAlternative) {
					maybeQname = QualifiedName.create((obj.eContainer as SumType).name, obj.name);
				}
				else {
					maybeQname = QualifiedName.create((obj as NamedElement).name);
				}
			}
		} 
		
		val qname = (maybeQname ?: QualifiedName.create(BaseUtils.getText(origin, reference)?.split("\\.")));
		return qname;
	}
	
	new(EObject origin, String name, EReference reference, QualifiedName qualifiedName) {
		this(origin, name, reference, qualifiedName, false);
	}
	
	override replaceProxies(ConstraintSystem system, (TypeVariableProxy) => Iterable<AbstractType> resolve) {
		//assertion based on control flow in ConstraintSystem.replaceProxies: this.origin.eIsProxy === false
		val candidates = resolve.apply(this);
		val resultType = if(candidates.size === 1) {
			candidates.head;
		}
		else {
			switch ambiguityResolutionStrategy {
				case UseFirst: candidates.head
				case UseLast: candidates.last
				case MakeNew: system.newTypeVariable(this.origin)
			}
		}
		
		if(this.origin.eClass.EReferences.contains(reference)) {			
			val currentEntry = this.origin.eGet(reference, false).castOrNull(EObject);
		 	if((currentEntry === null || currentEntry.eIsProxy) && resultType.origin !== null && resultType.origin !== this.origin) {
		 		val finalOrigin = this.origin;
				BaseUtils.ignoreChange(this.origin.eResource, [ 
					finalOrigin.eSet(reference, resultType.origin);
				]);
			}
		}
		
		return resultType;
	}
	
	override map((AbstractType)=>AbstractType f) {
		return f.apply(this);
	}
	
	override modifyNames((String) => String converter) {
		return new TypeVariableProxy(origin, converter.apply(name), reference, targetQID) => [
			it.ambiguityResolutionStrategy = this.ambiguityResolutionStrategy;
		];
	}
	
}