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

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.expressions.ExpressionsFactory
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.program.AbstractLoopStatement
import org.eclipse.mita.program.DoWhileStatement
import org.eclipse.mita.program.ForStatement
import org.eclipse.mita.program.ProgramFactory
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.WhileStatement

class PrepareLoopForFunctionUnvravelingStage extends AbstractTransformationStage {
	
	override getOrder() {
		ORDER_EARLY
	}
	
	protected dispatch def void doTransform(ForStatement expression) {
		expression.transformChildren();
		
		if(expression.condition.containsUnraveledObject) {
			rewriteLoop(expression, true, ProgramPackage.Literals.FOR_STATEMENT__CONDITION);
		}
		
		val plsWithFunctionCalls = expression.postLoopStatements.filter[ it.containsUnraveledObject ].toList();
		expression.postLoopStatements.removeAll(plsWithFunctionCalls);
		expression.body.content.addAll(plsWithFunctionCalls);
	}
	
	protected dispatch def void doTransform(WhileStatement expression) {
		expression.transformChildren();
		if(!expression.condition.containsUnraveledObject) return;
		
		rewriteLoop(expression, true, ProgramPackage.Literals.WHILE_STATEMENT__CONDITION);
	}
	
	protected dispatch def void doTransform(DoWhileStatement expression) {
		expression.transformChildren();
		if(!expression.condition.containsUnraveledObject) return;
		
		rewriteLoop(expression, false, ProgramPackage.Literals.DO_WHILE_STATEMENT__CONDITION);
	}
	
	protected def boolean containsUnraveledObject(EObject obj) {
		return obj.eAllContents.exists[ pipelineInfoProvider.willBeUnraveled(it) ]
	}
	
	def rewriteLoop(AbstractLoopStatement loop, boolean addBreakerInBeginning, EReference conditionReference) {
		val condition = loop.eGet(conditionReference) as Expression;
		val trueLiteral = ExpressionsFactory.eINSTANCE.createBoolLiteral();
		trueLiteral.value = true;
		val newCondition = ExpressionsFactory.eINSTANCE.createPrimitiveValueExpression();
		newCondition.value = trueLiteral;
		loop.eSet(conditionReference, newCondition);
		
		val breaker = ProgramFactory.eINSTANCE.createLoopBreakerStatement();
		breaker.condition = condition;
		
		if(addBreakerInBeginning) {
			loop.body.content.add(0, breaker);			
		} else {
			loop.body.content.add(breaker);
		}
	}
	
	
}