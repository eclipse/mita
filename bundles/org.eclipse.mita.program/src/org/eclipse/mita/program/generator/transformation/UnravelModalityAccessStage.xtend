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

import org.eclipse.mita.base.expressions.ArgumentExpression
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.TypeKind
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.program.AbstractStatement
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.ModalityAccessPreparation
import org.eclipse.mita.program.ProgramFactory

class UnravelModalityAccessStage extends AbstractUnravelingStage {
	
	public static int ORDER = ORDER_LATE
	
	override getOrder() {
		return ORDER;
	}
	
	override protected needsUnraveling(Expression expression) {
		if(expression instanceof ElementReferenceExpression) {
			val ref = expression.reference;
			if(ref instanceof GeneratedFunctionDefinition) {
				if(ref.generator.contains("ModalityReadGenerator")) {
					return true;
				}
			}
		}
		return false;
	}
	
	override protected createResultVariable(Expression unravelingObject) {
		/* TODO: This code makes very strict assumptions about the structure of the rewritten function call.
		 *       As such this code is very likely to break in the future.
		 */
		val firstArgument = (unravelingObject as ArgumentExpression).arguments.head?.value;
		val featureCall = firstArgument as ElementReferenceExpression;
		val modality = featureCall.reference as Modality;
		val systemResourceKind = (featureCall.arguments.head.value as ElementReferenceExpression).reference as TypeKind;
		val systemResource = systemResourceKind.kindOf as AbstractSystemResource;
		
		val result = ProgramFactory.eINSTANCE.createModalityAccessPreparation();
		result.modalities.add(modality);
		result.systemResource = systemResource;
		return result;
	}
	
	// We don't create a variable declaration but a modality access preparation, therefore we don't need to assign anything
	override protected AbstractStatement createAssignmentStatement(Expression varRef, Expression initialization) {
		return ProgramFactory.eINSTANCE.createNoopStatement();
	}
	
	override protected createResultVariableReference(AbstractStatement resultVariable) {
		val modalityAccessPreparation = resultVariable as ModalityAccessPreparation;
		
		val result = ProgramFactory.eINSTANCE.createModalityAccess();
		result.preparation = modalityAccessPreparation;
		result.modality = modalityAccessPreparation.modalities.head;
		return result;
	}	
}