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

import org.eclipse.mita.program.generator.transformation.AbstractTransformationStage
import org.eclipse.mita.base.expressions.StringLiteral

class EscapeWhitespaceInStringStage extends AbstractTransformationStage {
	
	override getOrder() {
		ORDER_VERY_EARLY
	}
	
	protected dispatch def void doTransform(StringLiteral literal) {
		/*
		 * Xtext interprets these special characters and forms strings which we can't
		 * properly generate code from. Thus we have to undo this interpretation. This
		 * really feels like a workaround though. Rather we should find out how disable
		 * this "interpretation" in the Xtext grammar.  
		 */
		literal.value = literal.value.replaceSpecialCharacters();
	}
	
	static def replaceSpecialCharacters(String str) {
		str.replace("\n", "\\n")
			.replace("\r", "\\r")
			.replace("\t", "\\t")
			.replace("\b", "\\b")
			.replace("\f", "\\f")
			.replace("\"", "\\\"");
	}
	
}