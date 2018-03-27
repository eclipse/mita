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

import org.yakindu.base.expressions.expressions.ExpressionsFactory
import org.yakindu.base.expressions.expressions.FeatureCall
import org.yakindu.base.types.Enumerator

/**
 * Converts FeatureCalls to operation call ElementReferenceExpressions.
 */
class ResolveEnumValuesStage extends AbstractTransformationStage {
	
	override getOrder() {
		ORDER_EARLY
	}
	
	protected dispatch def void doTransform(FeatureCall featureCall) {
		/*
		 * Rewrite this to an ElementReferenceExpression, thereby resolving an extension
		 * method call to an enum reference.
		 */
		if(featureCall.feature instanceof Enumerator) {
			// transform the featurecall owner and arguments before it losses its container
			featureCall.owner.doTransform;
			
			val enumerator = featureCall.feature as Enumerator;
			val elementRefExpr = ExpressionsFactory.eINSTANCE.createElementReferenceExpression;
			elementRefExpr.reference = enumerator;
			featureCall.replaceWith(elementRefExpr);
		}
		else {
			featureCall.transformChildren;
		}
	}
	
}