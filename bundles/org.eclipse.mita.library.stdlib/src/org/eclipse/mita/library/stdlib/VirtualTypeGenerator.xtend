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
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.generator.AbstractTypeGenerator

class VirtualTypeGenerator extends AbstractTypeGenerator {
	
	override checkExpressionSupport(EObject context, AbstractType type, AssignmentOperator operator, AbstractType otherType) {
		return false;
	}
	
	override generateTypeSpecifier(AbstractType type, EObject context) {
		return codeFragmentProvider.create('''VIRTUAL_TYPE_BREAKS_CODE''');
	}
	
	override generateNewInstance(AbstractType type, NewInstanceExpression expr) {
		return codeFragmentProvider.create('''''');
	}
	
}