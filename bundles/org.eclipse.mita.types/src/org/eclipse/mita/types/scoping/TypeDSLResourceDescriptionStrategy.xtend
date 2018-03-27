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

package org.eclipse.mita.types.scoping

import org.eclipse.mita.types.Exportable
import org.eclipse.mita.types.SumAlternative
import org.eclipse.mita.types.SumType
import com.google.common.collect.Maps
import java.util.List
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.resource.EObjectDescription
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.resource.impl.DefaultResourceDescriptionStrategy
import org.eclipse.xtext.util.IAcceptor
import org.yakindu.base.types.TypeSpecifier
import org.yakindu.base.types.TypedElement
import org.yakindu.base.types.TypesPackage

class TypeDSLResourceDescriptionStrategy extends DefaultResourceDescriptionStrategy {
	public static final String TYPE = "TYPE"
	public static final String EXPORTED = "EXPORTED"

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
	}

	static def String getTypeSpecifierType(TypeSpecifier specifier) {
		
		if(specifier instanceof org.eclipse.mita.types.TypeSpecifier){
			if(specifier.optional){
				return MitaTypeSystem.OPTINAL_TYPE
			}else if (!specifier.referenceModifiers.isEmpty){
				return MitaTypeSystem.REFERENCE_TYPE
			}
		}
		var List<INode> typeNode = NodeModelUtils.findNodesForFeature(specifier,
			TypesPackage.Literals.TYPE_SPECIFIER__TYPE)
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
