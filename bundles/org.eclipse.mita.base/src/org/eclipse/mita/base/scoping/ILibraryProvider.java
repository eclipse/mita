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

package org.eclipse.mita.base.scoping;

import org.eclipse.emf.common.util.URI;

/**
 * @author Christian Weichel - initial contribution and API
 */
public interface ILibraryProvider {

	/**
	 * @return a list of all libraries known to this system
	 */
	public Iterable<URI> getLibraries();

}
