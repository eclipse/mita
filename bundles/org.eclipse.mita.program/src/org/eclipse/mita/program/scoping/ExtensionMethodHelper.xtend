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

package org.eclipse.mita.program.scoping

import com.google.common.collect.Lists
import java.util.List
import org.eclipse.mita.base.expressions.Expression
import org.eclipse.mita.base.types.ComplexType
import org.eclipse.mita.base.types.NamedProductType
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.Type

class ExtensionMethodHelper {

	def combine(Expression first, List<Expression> others) {
		val args = Lists.newArrayList
		args += first
		args += others
		args
	}
	
	def isExtensionMethodOn(Operation operation, Type callerType) {
		if (callerType instanceof StructureType && (callerType as StructureType).parameters.contains(operation)) {
			// method contained by caller, means it is not an extension method
			return false;
		}
		if (callerType instanceof NamedProductType && (callerType as NamedProductType).parameters.contains(operation)) {
			// method contained by caller, means it is not an extension method
			return false;
		}
		if (callerType instanceof ComplexType && (callerType as ComplexType).allFeatures.contains(operation)) {
			// method contained by caller, means it is not an extension method
			return false;
		}
		return true;
	}
}
