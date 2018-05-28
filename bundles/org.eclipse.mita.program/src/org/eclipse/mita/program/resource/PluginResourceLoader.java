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

package org.eclipse.mita.program.resource;

import org.eclipse.core.runtime.Platform;
import org.eclipse.emf.ecore.resource.Resource;
import org.osgi.framework.Bundle;

import com.google.inject.Inject;
import com.google.inject.Injector;

public class PluginResourceLoader {

	@Inject
	protected Injector injector;
	
	public Object loadFromPlugin(Resource resource, String classname) {
		if (!resource.getURI().isPlatformPlugin() || classname == null || classname.isEmpty()) {
			// TODO: The resource is not located in a plugin so we can't load the generator class. Handle this.
			return null;
		}
		Bundle plugin = Platform.getBundle(resource.getURI().segment(1));
		try {
			Class<?> clasz = plugin.loadClass(classname);
			Object newInstance = clasz.newInstance();
			injector.injectMembers(newInstance);
			return newInstance;
		} catch (ClassNotFoundException | InstantiationException | IllegalAccessException e) {
			e.printStackTrace();
			return null;
		}
	}
	
}
