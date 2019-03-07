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

package org.eclipse.mita.base.scoping

import java.util.List
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.resource.ISelectable
import org.eclipse.xtext.scoping.IScope
import org.eclipse.xtext.scoping.impl.ImportNormalizer
import org.eclipse.xtext.scoping.impl.ImportScope
import org.eclipse.xtext.scoping.impl.ImportedNamespaceAwareLocalScopeProvider

class BaseImportScopeProvider extends ImportedNamespaceAwareLocalScopeProvider {
	// work around the fact that the base implementation assumes that each qualified name is unique in scope.
	// in our implementation they are unique up to being types or other objects.
	// this is pretty much only needed for serialization of virtual functions etc.
	override protected createImportScope(IScope parent, List<ImportNormalizer> namespaceResolvers, ISelectable importFrom, EClass type, boolean ignoreCase) {
		return new ImportScope(namespaceResolvers, parent, importFrom, type, ignoreCase) {
			
			override protected getLocalElementsByEObject(EObject object, URI uri) {
				var Iterable<IEObjectDescription> candidates = getImportFrom().getExportedObjectsByObject(object)
				val Iterable<IEObjectDescription> aliasedElements = getAliasedElements(candidates)
				// make sure that the element is returned when asked by name.
				return aliasedElements.filter[ input |
					val descriptions = getLocalElementsByName(input.getName())
					if(descriptions.nullOrEmpty) return false
					if(descriptions.exists[it.getEObjectOrProxy() === input.getEObjectOrProxy()]) return true
					if(descriptions.exists[input.getEObjectURI().equals(it.getEObjectURI())]) return true
					return false
				]
			}
			
		};
	}
}