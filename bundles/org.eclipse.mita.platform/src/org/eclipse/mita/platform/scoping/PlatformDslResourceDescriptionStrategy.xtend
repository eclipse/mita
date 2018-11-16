/** 
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 * Contributors:
 * Bosch Connected Devices and Solutions GmbH - initial contribution
 * SPDX-License-Identifier: EPL-2.0
 */
package org.eclipse.mita.platform.scoping

import com.google.common.collect.ImmutableList
import java.util.HashMap
import java.util.Map
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.scoping.BaseResourceDescriptionStrategy
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.SumType
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.types.VirtualFunction
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.platform.Platform
import org.eclipse.mita.platform.PlatformPackage
import org.eclipse.mita.platform.SystemResourceAlias
import org.eclipse.mita.platform.SystemSpecification
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.resource.EObjectDescription
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.util.IAcceptor

import static extension org.eclipse.mita.base.util.BaseUtils.force

class PlatformDslResourceDescriptionStrategy extends BaseResourceDescriptionStrategy {
	ImmutableList<EClass> SUPPRESSED_OBJECTS=ImmutableList.of()
	//			PlatformPackage.Literals.ABSTRACT_SYSTEM_RESOURCE, // we expose resources bound to the platform
	//			PlatformPackage.Literals.BUS, // we expose resources bound to the platform
	//			PlatformPackage.Literals.CONNECTIVITY, // we expose resources bound to the platform
	//			PlatformPackage.Literals.INPUT_OUTPUT, // we expose resources bound to the platform
	//			PlatformPackage.Literals.SENSOR, // we expose resources bound to the platform
	//			PlatformPackage.Literals.SYSTEM_RESOURCE_ALIAS // we expose resources bound to the platform
	def package void export(EObject obj, IAcceptor<IEObjectDescription> acceptor) {
		var Map<String, String> map=new HashMap() 
		map.put(EXPORTED, String.valueOf(true)) 
		var QualifiedName firstQN=getQualifiedNameProvider().getFullyQualifiedName(obj) 
		acceptor.accept(EObjectDescription.create(firstQN, obj, map)) 
		var QualifiedName secondQN=typeQualifiedNameProvider.getFullyQualifiedName(obj) 
		if (secondQN !== null && !secondQN.equals(firstQN)) {
			acceptor.accept(EObjectDescription.create(secondQN, obj, map)) 
		}
	}
	override boolean createEObjectDescriptions(EObject eObject, IAcceptor<IEObjectDescription> acceptor) {
		if (getQualifiedNameProvider() === null) {
			return false 
		}
		if (SUPPRESSED_OBJECTS.contains(eObject.eClass())) {
			// we want to suppress this object, don't export it
			return false 
		} else if (eObject instanceof SystemSpecification) {
			return createPlatformDescription(eObject, acceptor) 
		} else if ((eObject instanceof StructureType) || (eObject instanceof SumAlternative) || (eObject instanceof SumType) || (eObject.eContainer() instanceof SumAlternative && !(eObject instanceof TypeSpecifier)) || (eObject instanceof VirtualFunction)) {
			export(eObject, acceptor) 
			return true 
		} else {
			return super.createEObjectDescriptions(eObject, acceptor) 
		}
	}
	def private boolean createPlatformDescription(SystemSpecification systemSpecification, IAcceptor<IEObjectDescription> acceptor) {
		val platformDefinitions = systemSpecification.resources.filter(Platform);
		val exportedResourceNames = platformDefinitions.flatMap[
			NodeModelUtils.findNodesForFeature(it, PlatformPackage.eINSTANCE.platform_Resources).map[it?.text?.trim];
		].reject[it.nullOrEmpty].force.toSet
		
		val localResourceScope = systemSpecification.resources.reject[it instanceof SystemResourceAlias].toMap([it.name], [it])
		
		val exportedResources = systemSpecification.resources
			.filter[it instanceof Platform || exportedResourceNames.contains(it.name)]

		exportedResources.forEach[
			super.createEObjectDescriptions(it, acceptor);
			if(it instanceof SystemResourceAlias) {
				val originalResourceName = NodeModelUtils.findNodesForFeature(it, PlatformPackage.eINSTANCE.systemResourceAlias_Delegate).head?.text?.trim;
				if(!originalResourceName.nullOrEmpty) {
					it.createAdditionalDescriptions(localResourceScope.get(originalResourceName).modalities, acceptor)	
				}
			}
			else {
				it.createAdditionalDescriptions(it.modalities, acceptor);
			}]
		
		return !exportedResources.empty;
	}
	
	dispatch def createAdditionalDescriptions(SystemResourceAlias systemResource, Iterable<Modality> modalities, IAcceptor<IEObjectDescription> acceptor) {
		
		// export all modalities the system resource has
		for (Modality m : modalities.filterNull) {
			var QualifiedName qnSystemResource = getQualifiedNameProvider().getFullyQualifiedName(systemResource) 
			var QualifiedName qn = qnSystemResource.append(m.getName()) 
			var Map<String, String> map=new HashMap() 
			map.put(EXPORTED, String.valueOf(true)) 
			acceptor.accept(EObjectDescription.create(qn, m, map)) 
		}
	}
	
	
	dispatch def createAdditionalDescriptions(AbstractSystemResource systemResource, Iterable<Modality> modalities, IAcceptor<IEObjectDescription> acceptor) {
		for (Modality m : modalities.filterNull) {
			super.createEObjectDescriptions(m, acceptor)
		}
	} 
}