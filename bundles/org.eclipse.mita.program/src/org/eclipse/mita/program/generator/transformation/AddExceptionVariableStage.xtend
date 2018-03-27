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

import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.ProgramFactory
import org.eclipse.mita.program.TryStatement
import org.eclipse.xtext.EcoreUtil2

class AddExceptionVariableStage extends AbstractTransformationStage {

	override getOrder() {
		ORDER_EARLY
	}

	protected dispatch def void doTransform(ProgramBlock block) {
		/*
		 * If there is the root program block (no program block ancestor), we need to add the exception handling variable.
		 */
		val parentBlock = EcoreUtil2.getContainerOfType(block.eContainer, ProgramBlock);
		val isRootBlock = parentBlock === null || parentBlock == block;
		if (isRootBlock) {
			var exceptionVar = ProgramFactory.eINSTANCE.createExceptionBaseVariableDeclaration
			exceptionVar.name = 'exception';
			exceptionVar.needsReturnFromTryCatch = !EcoreUtil2.getAllContentsOfType(block, TryStatement).empty;
			block.content.add(0, exceptionVar);
		}
	}

}
