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

package org.eclipse.mita.platform.scoping;

import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.xtext.resource.IEObjectDescription;
import org.eclipse.xtext.util.IAcceptor;

import org.eclipse.mita.platform.AbstractSystemResource;
import org.eclipse.mita.platform.Platform;
import org.eclipse.mita.platform.PlatformPackage;
import org.eclipse.mita.platform.SystemResourceAlias;
import org.eclipse.mita.types.scoping.TypeDSLResourceDescriptionStrategy;
import com.google.common.collect.ImmutableList;

public class PlatformDslResourceDescriptionStrategy extends TypeDSLResourceDescriptionStrategy {

	private ImmutableList<EClass> SUPPRESSED_OBJECTS = ImmutableList.of(
			PlatformPackage.Literals.ABSTRACT_SYSTEM_RESOURCE, // we expose resources bound to the platform
			PlatformPackage.Literals.BUS, // we expose resources bound to the platform
			PlatformPackage.Literals.CONNECTIVITY, // we expose resources bound to the platform
			PlatformPackage.Literals.INPUT_OUTPUT, // we expose resources bound to the platform
			PlatformPackage.Literals.SENSOR, // we expose resources bound to the platform
			PlatformPackage.Literals.SYSTEM_RESOURCE_ALIAS // we expose resources bound to the platform
			);

	@Override
	public boolean createEObjectDescriptions(EObject eObject, IAcceptor<IEObjectDescription> acceptor) {
		if (getQualifiedNameProvider() == null) {
			return false;			
		}

		if(SUPPRESSED_OBJECTS.contains(eObject.eClass())) {
			// we want to suppress this object, don't export it
			return false;
		} else if(eObject instanceof Platform) {
			return createPlatformDescription((Platform) eObject, acceptor);
		} else {
			return super.createEObjectDescriptions(eObject, acceptor);			
		}
	}

	private boolean createPlatformDescription(Platform platform, IAcceptor<IEObjectDescription> acceptor) {
		// Export the platform itself
		super.createEObjectDescriptions(platform, acceptor);
		
		// Export all resources the platform has
		for(AbstractSystemResource systemResource : platform.getResources()) {
			if(systemResource == null || (systemResource instanceof SystemResourceAlias && ((SystemResourceAlias) systemResource).getDelegate() == null)) continue;
			super.createEObjectDescriptions(systemResource, acceptor);
		}
		
		return true;
	}

}
