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

import org.eclipse.mita.program.generator.AbstractTypeGenerator
import org.yakindu.base.types.TypeSpecifier
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.emf.ecore.EObject
import org.yakindu.base.expressions.expressions.AssignmentOperator

class VirtualTypeGenerator extends AbstractTypeGenerator {
	
	override checkExpressionSupport(TypeSpecifier type, AssignmentOperator operator, TypeSpecifier otherType) {
		return false;
	}
	
	override generateTypeSpecifier(TypeSpecifier type, EObject context) {
		return codeFragmentProvider.create('''VIRTUAL_TYPE_BREAKS_CODE''');
	}
	
	override generateNewInstance(TypeSpecifier type, NewInstanceExpression expr) {
		return codeFragmentProvider.create('''''');
	}
	
}