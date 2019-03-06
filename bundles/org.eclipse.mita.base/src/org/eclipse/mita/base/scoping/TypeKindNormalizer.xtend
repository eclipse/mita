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

import org.eclipse.xtext.scoping.impl.ImportNormalizer
import org.eclipse.xtext.naming.QualifiedName

class TypeKindNormalizer extends ImportNormalizer {
	
	new(QualifiedName importedNamespace, boolean wildCard, boolean ignoreCase) {
		super(importedNamespace, wildCard, ignoreCase)
	}
	
	new() {
		super(QualifiedName.create("∗"), true, false);
	}
	
	override deresolve(QualifiedName fullyQualifiedName) {
		if(fullyQualifiedName.firstSegment.startsWith("∗")) {
			return QualifiedName.create(fullyQualifiedName.firstSegment.substring(1)).append(fullyQualifiedName.skipFirst(1));
		}
		return fullyQualifiedName;
	}
	
	override resolve(QualifiedName relativeName) {
		if (relativeName.isEmpty()) {
			return null;
		}
		
		return QualifiedName.create("∗" + relativeName.firstSegment).append(relativeName.skipFirst(1));
		
	}
	
}
