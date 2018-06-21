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

import org.eclipse.mita.program.AbstractStatement
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.ProgramFactory
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.Expression
import org.eclipse.mita.base.expressions.ExpressionsFactory

abstract class AbstractUnravelingStage extends AbstractTransformationStage {
	
	override getOrder() {
		ORDER_LATE
	}
	
	protected override void doTransform(EObject obj) {
		// We do not unravel expressions in a setup block
		val inSetupBlock = EcoreUtil2.getContainerOfType(obj, SystemResourceSetup) !== null;
		if(inSetupBlock) return;
		
		/* It's important to unravel the children depth first so that we have their results available
		 * as ElementReferenceExpressions - thus generated code will collapse to a legal C expression.
		 */ 
		obj.transformChildren();
		
		
		if(obj instanceof Expression) {
			if(needsUnraveling(obj)) {
				doUnravel(obj);
			}			
		}
	}
	
	/**
	 * Called during the transformation to find out if an expression needs unraveling
	 */
	abstract protected def boolean needsUnraveling(Expression expression)
	
	protected def void doUnravel(Expression obj) {
		/* Unraveling means that we pull an expression out of its tree and place it in a variable created for
		 * this expression beforehand. By default we use the original expression (the expression being unraveled)
		 * as initialization for this result variable.
		 * 
		 * If you as an implementer of an unraveling stage need a different behavior, please override createInitialization.
		 */
		val unraveledInitialization = createInitialization(obj);
		
		/* The result variable will later be inserted in the parent block just before the expression tree that contained
		 * the expression we're currently unraveling. We'll choose a unique name for the variable based on some heuristics.
		 * 
		 * If you want to change the name generated, override getUniqueVariableName.
		 * If you need special behavior regarding the result variable itself, override createResultVariable. 
		 */
		val resultVariable = createResultVariable(obj, unraveledInitialization);
		val resultVariableReference = createResultVariableReference(resultVariable);
		
		/* We have to find the insertion point for the resultVariable before we replace the unraveling object with the
		 * reference to the result variable and thus make it impossible to find the original context.
		 */
		val originalContext = findOriginalContext(obj);
		obj.replaceWith(resultVariableReference);
		
		/* Inserting the result variable itself is a post transformation as it modifies the children
		 * of its container and thus would lead to a ConcurrentModificationException.
		 * 
		 * Note how by calling transformChildren (in doTransform) before doUnravel we transform depth first and
		 * thus maintain the correct order of result variables (as all inserting post transformations are in the
		 * correct order). This way initialization code which references other unraveled code (e.g. f(g(h(x))))
		 * will reference existing result variables.
		 */
		addPostTransformation([ insertNextToParentBlock(originalContext, true, resultVariable) ]);
	}
	
	protected def Expression createResultVariableReference(EObject resultVariable) {
		val resultVariableReference = ExpressionsFactory.eINSTANCE.createElementReferenceExpression;
		resultVariableReference.reference = resultVariable;
		return resultVariableReference;
	}
	
	/**
	 * Creates the expression that serves as initialization for the result variable of
	 * the unraveled operation.
	 * 
	 * BEWARE: This function must not simply return the expression it is given as that
	 * expression will later be replaced, so we'd be left with a variable without initialization. 
	 */
	protected def Expression createInitialization(Expression expression) {
		val copy = EcoreUtil2.copy(expression);
		copier.linkOrigin(copy, copier.getOrigin(expression));
		return copy;
	}
	
	protected def AbstractStatement createResultVariable(Expression unravelingObject, Expression initialization) {
		val resultVariableName = getUniqueVariableName(unravelingObject);
		val resultVariable = ProgramFactory.eINSTANCE.createVariableDeclaration;
		resultVariable.name = resultVariableName;
		resultVariable.initialization = initialization;
		return resultVariable;
	}
	
	protected def getUniqueVariableName(Expression unravelingObject) {
		val variableDeclarationContainer = EcoreUtil2.getContainerOfType(unravelingObject, VariableDeclaration);
		val uid = String.valueOf(unravelingObject.hashCode);
		val resultName = (if(variableDeclarationContainer === null) {
			val candidate = EcoreUtil2.getID(unravelingObject);
			if(candidate === null) {
				if(unravelingObject instanceof ElementReferenceExpression) {
					EcoreUtil2.getID(unravelingObject.reference);
				} else {
					null;
				}
			} else {
				candidate;
			}
		} else {
			variableDeclarationContainer.name;
		})?.toLowerCase?.split("\\.")?.last
		val resultSuffix = if(resultName === null) 'result' else 'Result';
		val result = '''«resultName»«resultSuffix»«uid»''';
		return result;
	}
	
	protected def findOriginalContext(EObject unravelingObject) {
		var originalContext = unravelingObject.eContainer;
		while(originalContext.eContainer !== null && !(originalContext.eContainer instanceof ProgramBlock)) {
			originalContext = originalContext.eContainer;
		}
		return originalContext;
	}
	
}