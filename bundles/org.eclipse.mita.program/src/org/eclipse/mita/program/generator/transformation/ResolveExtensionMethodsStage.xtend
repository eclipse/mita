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

import org.eclipse.mita.base.expressions.ExpressionsFactory
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.types.Operation

/**
 * Converts FeatureCalls to operation call ElementReferenceExpressions.
 */
class ResolveExtensionMethodsStage extends AbstractTransformationStage {
	
	override getOrder() {
		ORDER_EARLY
	}
	
	protected dispatch def void doTransform(FeatureCall featureCall) {
		if(featureCall.isOperationCall && featureCall.feature instanceof Operation) {
			/*
			 * Rewrite this to an ElementReferenceExpression, thereby resolving an extension
			 * method call to a regular operation call.
			 */
			val function = featureCall.feature as Operation;
			
			// transform the featurecall owner and arguments before it losses its container
			featureCall.owner.doTransform;
			featureCall.arguments.forEach[x | x.value?.doTransform ]
			
			val firstArg = ExpressionsFactory.eINSTANCE.createArgument;
			firstArg.parameter = function.parameters.head;
			firstArg.value = featureCall.owner;
			
			val elementRefExpr = ExpressionsFactory.eINSTANCE.createElementReferenceExpression;
			elementRefExpr.operationCall = true;
			elementRefExpr.reference = function;
			elementRefExpr.arguments.add(firstArg);
			elementRefExpr.arguments.addAll(featureCall.arguments);
			featureCall.replaceWith(elementRefExpr);
		} else {
			featureCall.transformChildren
		}
	}
	
}