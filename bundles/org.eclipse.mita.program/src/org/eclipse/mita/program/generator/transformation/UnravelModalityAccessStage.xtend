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

import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.ProgramFactory
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.Expression
import org.eclipse.mita.base.expressions.ArgumentExpression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.program.ModalityAccessPreparation

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
	
	override protected createResultVariable(Expression unravelingObject, Expression initialization) {
		/* TODO: This code makes very strict assumptions about the structure of the rewritten function call.
		 *       As such this code is very likely to break in the future.
		 */
		val firstArgument = (unravelingObject as ArgumentExpression).arguments.head?.value;
		val featureCall = firstArgument as FeatureCall
		val modality = featureCall.feature as Modality;
		val systemResource = (featureCall.owner as ElementReferenceExpression).reference as AbstractSystemResource;
		
		val result = ProgramFactory.eINSTANCE.createModalityAccessPreparation();
		result.modalities.add(modality);
		result.systemResource = systemResource;
		return result;
	}
	
	override protected createResultVariableReference(EObject resultVariable) {
		val modalityAccessPreparation = resultVariable as ModalityAccessPreparation;
		
		val result = ProgramFactory.eINSTANCE.createModalityAccess();
		result.preparation = modalityAccessPreparation;
		result.modality = modalityAccessPreparation.modalities.head;
		return result;
	}
	
}