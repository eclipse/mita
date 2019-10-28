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

package org.eclipse.mita.program.generator

import org.eclipse.mita.program.ProgramFactory
import org.eclipse.mita.program.generator.internal.ProgramCopier
import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.generator.trace.node.TracedAccessors

@TracedAccessors(ProgramFactory)
class ProgramDslTraceExtensions {

	override location(EObject obj) {
		var original = ProgramCopier.getOrigin(obj);
		if(original?.eResource !== null) {
			return super.location(original);
		}
		return super.location(obj);
	}

}
