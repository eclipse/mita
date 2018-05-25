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

package org.eclipse.mita.program.generator.transformation

import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.program.NewInstanceExpression

class ResolveGeneratedTypeConstructorStage extends AbstractTransformationStage {
	
	override getOrder() {
		ORDER_EARLY
	}
	
	protected dispatch def void doTransform(NewInstanceExpression expression) {
		val expressionType = expression.type?.type;
		if(expressionType instanceof GeneratedType) {
			expression.reference = expressionType.constructor;
		}
	}
	
}