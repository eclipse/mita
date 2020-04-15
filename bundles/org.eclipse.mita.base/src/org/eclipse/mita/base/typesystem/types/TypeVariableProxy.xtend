/********************************************************************************
 * Copyright (c) 2018, 2019 Robert Bosch GmbH & TypeFox GmbH
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH & TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.emf.ecore.impl.BasicEObjectImpl
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.base.util.Left
import org.eclipse.mita.base.util.Right
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtext.naming.QualifiedName

import static extension org.eclipse.mita.base.util.BaseUtils.castOrNull

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
	new(EObject origin, int idx, EReference reference, QualifiedName targetQID, boolean isLinkingProxy) {
		this(origin, idx, reference, targetQID, isLinkingProxy, null);
	}
	new(EObject origin, int idx, EReference reference, QualifiedName targetQID, boolean isLinkingProxy, String name) {
		super(origin, idx, name);
		this.reference = reference;
		this.targetQID = targetQID;
		this.isLinkingProxy = isLinkingProxy;
		if(targetQID?.toString.nullOrEmpty) {
			//throw new IllegalArgumentException("targetQID null or empty");
		}
		if(origin === null) {
			throw new NullPointerException
		}
	}
	
	new(EObject origin, int idx, EReference reference, QualifiedName targetQID, AmbiguityResolutionStrategy ambiguityResolutionStrategy, boolean isLinkingProxy) {
		this(origin, idx, reference, targetQID, ambiguityResolutionStrategy, isLinkingProxy, null);
	}
	new(EObject origin, int idx, EReference reference, QualifiedName targetQID, AmbiguityResolutionStrategy ambiguityResolutionStrategy, boolean isLinkingProxy, String name) {
		this(origin, idx, reference, targetQID, isLinkingProxy, name);
		this.ambiguityResolutionStrategy = ambiguityResolutionStrategy;
	}
	
	new(EObject origin, int idx, EReference reference) {
		this(origin, idx, reference, TypeVariableProxy.getQName(origin, reference), true);
	}
	
	new(EObject origin, int idx, EReference reference, QualifiedName qualifiedName) {
		this(origin, idx, reference, qualifiedName, true);
	}
	
	override replaceOrigin(EObject origin) {
		return new TypeVariableProxy(origin, idx, reference, targetQID, ambiguityResolutionStrategy, isLinkingProxy, name);
	}

	public static def getQName(EObject origin, EReference reference) {
		var QualifiedName maybeQname; 
		if(!origin.eIsProxy) {
			val obj = origin.eGet(reference, false);
			if(obj instanceof NamedElement && obj instanceof EObject && !(obj as EObject).eIsProxy) {
				if(obj instanceof SumAlternative) {
					maybeQname = QualifiedName.create((obj.eContainer as org.eclipse.mita.base.types.SumType).name, obj.name);
				}
				else {
					maybeQname = QualifiedName.create((obj as NamedElement).name);
				}
			}
		} 
		
		val qname = (maybeQname ?: QualifiedName.create(BaseUtils.getText(origin, reference)?.split("\\.")));
		return qname;
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
		 		// If result is proxy and previous is proxy, set the previous proxy's uri to the result's proxy uri
		 		if(resultType.origin.eIsProxy) {
		 			if(currentEntry !== null && currentEntry.eIsProxy) {
		 				val newProxyUri = resultType.origin.castOrNull(BasicEObjectImpl).eProxyURI;
		 				if(newProxyUri !== null) {
		 					BaseUtils.ignoreChange(this.origin.eResource, [ 
				 				currentEntry.castOrNull(BasicEObjectImpl)?.eSetProxyURI(newProxyUri);
							]);
						}
		 			}
		 		}
		 		// otherwise we have a real object, so assign it (i.e. link)
		 		else {
			 		val finalOrigin = this.origin;
					BaseUtils.ignoreChange(this.origin.eResource, [ 
						finalOrigin.eSet(reference, resultType.origin);
					]);
				}
			}
		}
		
		return resultType;
	}
	
	override map((AbstractType)=>AbstractType f) {
		return f.apply(this);
	}
	
	override modifyNames(NameModifier converter) {
		val newName = converter.apply(idx);
		if(newName instanceof Left<?, ?>) {
			return new TypeVariableProxy(origin, (newName as Left<Integer, String>).value, reference, targetQID, ambiguityResolutionStrategy, isLinkingProxy, name);
		}
		else {
			return new TypeVariableProxy(origin, idx, reference, targetQID, ambiguityResolutionStrategy, isLinkingProxy, (newName as Right<Integer, String>).value);
		}
	}
	
	override getToStringPrefix() {
		return "p_";
	}
}