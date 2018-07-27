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

package org.eclipse.mita.library.stdlib

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.generator.AbstractTypeGenerator

class VirtualTypeGenerator extends AbstractTypeGenerator {
	
	override checkExpressionSupport(PresentTypeSpecifier type, AssignmentOperator operator, PresentTypeSpecifier otherType) {
		return false;
	}
	
	override generateTypeSpecifier(PresentTypeSpecifier type, EObject context) {
		return codeFragmentProvider.create('''VIRTUAL_TYPE_BREAKS_CODE''');
	}
	
	override generateNewInstance(PresentTypeSpecifier type, NewInstanceExpression expr) {
		return codeFragmentProvider.create('''''');
	}
	
}