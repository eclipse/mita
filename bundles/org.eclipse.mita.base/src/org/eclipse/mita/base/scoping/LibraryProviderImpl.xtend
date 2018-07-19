/** 
 * Copyright (c) 2018 TypeFox GmbH.
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 * Contributors:
 * TypeFox GmbH - initial contribution
 * SPDX-License-Identifier: EPL-2.0
 */
package org.eclipse.mita.base.scoping

import org.eclipse.emf.common.util.URI
import org.eclipse.mita.library.^extension.LibraryExtensions

/** 
 * @author Christian Weichel - initial contribution and API
 */
class LibraryProviderImpl implements ILibraryProvider {
	
	override Iterable<URI> getLibraries() {
		/* until we have sorted out the package management, the default implementation resorts to the
		 * extension point mechanism.
		 */
		LibraryExtensions::getDescriptors().flatMap[ it.resourceUris ];
	}
	
}
