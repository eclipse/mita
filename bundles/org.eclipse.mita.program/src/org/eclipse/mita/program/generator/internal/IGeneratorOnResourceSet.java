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

package org.eclipse.mita.program.generator.internal;

import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.ResourceSet;
import org.eclipse.xtext.generator.IFileSystemAccess2;
import org.eclipse.xtext.generator.IGenerator2;
import org.eclipse.xtext.xbase.lib.Functions.Function1;

/**
 * Generates text from all resources in a resource set.
 */
public interface IGeneratorOnResourceSet extends IGenerator2 {

	/**
     * @param input - the input for which to generate resources
     * @param fsa - file system access to be used to generate files
     */
    public void doGenerate(ResourceSet input, IFileSystemAccess2 fsa);
    
    /**
     * @param input - the input for which to generate resources
     * @param fsa - file system access to be used to generate files
     * @param includeInBuildPredicate - predicate to exclude resources in the resource set from being built
     */
    public void doGenerate(ResourceSet input, IFileSystemAccess2 fsa, Function1<Resource, Boolean> includeInBuildPredicate);
	
}
