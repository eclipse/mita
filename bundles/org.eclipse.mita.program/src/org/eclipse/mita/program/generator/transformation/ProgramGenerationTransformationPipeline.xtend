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

import org.eclipse.mita.program.Program
import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.yakindu.base.expressions.expressions.Expression

class ProgramGenerationTransformationPipeline implements ITransformationPipelineInfoProvider {
	
	@Inject AddExceptionVariableStage addExceptionVariableStage
	@Inject EscapeWhitespaceInStringStage escapeWhitespaceInStringStage
	@Inject UnravelModalityAccessStage unravelModalityAccessStage
	@Inject GroupModalityAccessStage groupModalityAccessStage
	@Inject ResolveExtensionMethodsStage resolveExtensionMethodsStage
	@Inject ResolveGeneratedTypeConstructorStage resolveGeneratedTypeConstructorStage
	@Inject UnravelFunctionCallsStage unravelFunctionCallsStage
	@Inject UnravelInterpolatedStringsStage unravelInterpolatedStringsStage
	@Inject ResolveEnumValuesStage resolveEnumValuesStage
	@Inject PrepareLoopForFunctionUnvravelingStage prepareLoopForFunctionUnvravelingStage
	@Inject PrepareArrayRuntimeChecksStage prepareArrayRuntimeChecksStage
	@Inject UnravelLiteralArrayReturnStage unravelLiteralArrayReturnStage
	@Inject EnforceOperatorPrecedenceStage enforceOperatorPrecedenceStage

	public def transform(Program program) {
		val stages = getOrderedStages();

		var result = program;
		for(stage : stages) {
			result = stage.transform(this, result);
		}
		return result;
	}
	
	public override boolean willBeUnraveled(EObject obj) {
		if(obj instanceof Expression) {
			for(stage : orderedStages) {
				if(stage instanceof AbstractUnravelingStage) {
					if(stage.needsUnraveling(obj)) {
						return true;
					}
				}
			}
		}

		return false;
	}

	/**
	 * Takes the inject stages and sorts them based on their annotations.
	 */

	protected def getOrderedStages() {
		return #[
			addExceptionVariableStage,
			escapeWhitespaceInStringStage,
			unravelModalityAccessStage,
			groupModalityAccessStage,
			resolveExtensionMethodsStage,
			resolveGeneratedTypeConstructorStage,
			unravelFunctionCallsStage,
			unravelInterpolatedStringsStage,
			resolveEnumValuesStage,
			prepareLoopForFunctionUnvravelingStage,
			prepareArrayRuntimeChecksStage,
			unravelLiteralArrayReturnStage,
			enforceOperatorPrecedenceStage
		].sortBy[ x | x.order ];
	}

}
