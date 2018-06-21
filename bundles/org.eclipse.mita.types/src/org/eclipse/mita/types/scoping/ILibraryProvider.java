/********************************************************************************
 * Copyright (c) 2018 TypeFox GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.types.scoping;

import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.mita.types.ImportStatement;

/**
 * @author Christian Weichel - initial contribution and API
 */
public interface ILibraryProvider {

	/**
	 * @return a list of libraries which are imported by default
	 */
	public Iterable<URI> getDefaultLibraries();
	
	/**
	 * Computes a list of libraries imported by this resource.
	 * 
	 * <p><b>Note:</b> users expect the {@Link #getDefaultLibraries()} to be imported as well. Those libraries will not be included in the list computed by this function.</p>
	 * 
	 * @param resource the resource which contains explicit imports ({@link ImportStatement}).
	 * @return a list of resource URIs of explicitly imported libraries
	 */
	public Iterable<URI> getImportedLibraries(Resource context);
	
}
