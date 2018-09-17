/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.base.scoping

import com.google.common.collect.Maps
import com.google.inject.Inject
import java.util.List
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.Exportable
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.SumType
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.types.TypedElement
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.typesystem.IConstraintFactory
import org.eclipse.mita.base.typesystem.serialization.SerializationAdapter
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.resource.EObjectDescription
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.resource.impl.DefaultResourceDescriptionStrategy
import org.eclipse.xtext.util.IAcceptor

class BaseResourceDescriptionStrategy extends DefaultResourceDescriptionStrategy {
	public static final String TYPE = "TYPE"
	public static final String EXPORTED = "EXPORTED"
	public static final String CONSTRAINTS = "CONSTRAINTS";
	
	@Inject 
	protected TypeQualifiedNameProvider typeQualifiedNameProvider;
	
	@Inject
	protected IConstraintFactory constraintFactory;
	
	@Inject 
	protected SerializationAdapter serializationAdapter
	
	def void defineUserData(EObject eObject, Map<String, String> userData) {
		if (eObject instanceof TypedElement) {
			userData.put(TYPE, getTypeSpecifierType(((eObject as TypedElement)).getTypeSpecifier()))
		}
		if (eObject instanceof Exportable) {
			userData.put(EXPORTED, Boolean.toString(eObject.exported));
		}
		else if(eObject instanceof SumAlternative) {
			userData.put(EXPORTED, Boolean.toString((eObject.eContainer as SumType).exported));
		} else {
			userData.put(EXPORTED, Boolean.toString(true));
		}
		
		if (eObject.eContainer() === null) {
			// we're at the top level element - let's compute constraints and put that in a new EObjectDescription
			constraintFactory.setIsLinking(true)
			constraintFactory.getTypeRegistry().setIsLinking(true)
			val constraints = constraintFactory.create(eObject)
			val String json = serializationAdapter.toJSON(constraints)
			userData.put(CONSTRAINTS, json)
			
			val String constraintsBackOut = serializationAdapter.toJSON(serializationAdapter.fromJSON(json, null))
			if (json != constraintsBackOut) {
				throw new RuntimeException("Constraint serialization was not invariant")
			}
		}
	}

	static def String getTypeSpecifierType(TypeSpecifier specifier) {
		if(specifier instanceof PresentTypeSpecifier){
			if(specifier.optional){
				return MitaTypeSystem.OPTINAL_TYPE
			}else if (!specifier.referenceModifiers.isEmpty){
				return MitaTypeSystem.REFERENCE_TYPE
			}
		}
		var List<INode> typeNode = NodeModelUtils.findNodesForFeature(specifier,
			TypesPackage.Literals.PRESENT_TYPE_SPECIFIER__TYPE)
		if (typeNode.size() === 1) {
			return typeNode.get(0).getText().trim()
		} else {
			return "void"
		}
	}

	override boolean createEObjectDescriptions(EObject eObject, IAcceptor<IEObjectDescription> acceptor) {
		return createEObjectDescriptions(eObject, acceptor, qualifiedNameProvider);
	}

	def boolean createEObjectDescriptions(EObject eObject, IAcceptor<IEObjectDescription> acceptor, IQualifiedNameProvider nameProvider) {
		if(getQualifiedNameProvider() === null) return false
		if(!shouldCreateDescription(eObject)) return false
		
		try {
			var QualifiedName qualifiedName = nameProvider.getFullyQualifiedName(eObject)
			if (qualifiedName !== null) {
				var Map<String, String> userData = Maps.newHashMap()
				defineUserData(eObject, userData)
				acceptor.accept(EObjectDescription.create(qualifiedName, eObject, userData))
				val secondQN = typeQualifiedNameProvider.getFullyQualifiedName(eObject);
				if(secondQN !== null && secondQN != qualifiedName) {
					acceptor.accept(EObjectDescription.create(secondQN, eObject, userData))
				}
			}
		} catch (Exception exc) {
			exc.printStackTrace()
		}

		return true
	}

	def protected boolean shouldCreateDescription(EObject object) {
		return true
	}
}
