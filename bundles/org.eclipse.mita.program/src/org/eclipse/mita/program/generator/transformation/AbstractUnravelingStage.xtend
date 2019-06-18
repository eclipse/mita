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

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.AbstractStatement
import org.eclipse.mita.base.expressions.BinaryExpression
import org.eclipse.mita.base.expressions.ConditionalExpression
import org.eclipse.mita.base.expressions.ExpressionsFactory
import org.eclipse.mita.base.expressions.LogicalOperator
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.ProgramFactory
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.internal.ProgramCopier
import org.eclipse.xtext.EcoreUtil2

abstract class AbstractUnravelingStage extends AbstractTransformationStage {

	@Inject
	protected GeneratorUtils generatorUtils

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

		if (obj instanceof Expression) {
			if (needsUnraveling(obj)) {
				doUnravel(obj);
			}
		}
	}

	dispatch def getCondition(EObject obj, BinaryExpression logicalBinaryExpression) {
		if (logicalBinaryExpression.leftOperand === obj || logicalBinaryExpression.leftOperand?.eAllContents.findFirst [
			it === obj
		] !== null) {
			return null;
		}
		return getCondition(obj, logicalBinaryExpression, logicalBinaryExpression.operator);
	}

	dispatch def getCondition(EObject obj, BinaryExpression logicalBinaryExpression, LogicalOperator op) {
		val condition = EcoreUtil2.copy(logicalBinaryExpression.leftOperand);
		ProgramCopier.linkOrigin(condition, ProgramCopier.getOrigin(logicalBinaryExpression.leftOperand));
		if (logicalBinaryExpression.operator == LogicalOperator.AND) {
			// only execute if left was true
			return condition
		} else {
			// only execute if left was false
			return ExpressionsFactory.eINSTANCE.createLogicalNotExpression => [
				it.operand = condition;
			]
		}
	}

	dispatch def getCondition(EObject obj, BinaryExpression logicalBinaryExpression, Object op) {
		return null;
	}

	dispatch def getCondition(EObject obj, ConditionalExpression expr) {
		if ((#[expr.trueCase, expr.falseCase] + expr.trueCase?.eAllContents.toIterable ?:
			#[] + expr.falseCase?.eAllContents.toIterable ?: #[]).findFirst[it === obj] === null) {
			return null;
		}
		val negate = expr.falseCase === obj || expr.falseCase?.eAllContents.findFirst[it === obj] !== null;
		return getCondition(obj, expr, negate);
	}

	dispatch def getCondition(EObject obj, ConditionalExpression expr, boolean negate) {
		val condition = EcoreUtil2.copy(expr.condition);
		ProgramCopier.linkOrigin(condition, ProgramCopier.getOrigin(expr.condition));

		if (negate) {
			return ExpressionsFactory.eINSTANCE.createLogicalNotExpression => [
				it.operand = condition;
			];
		} else {
			return condition;
		}
	}

	dispatch def getCondition(EObject obj, Void nul) {
		return null
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
		 *
		 * The result variable will later be inserted in the parent block just before the expression tree that contained
		 * the expression we're currently unraveling. We'll choose a unique name for the variable based on some heuristics.
		 * 
		 * If you want to change the name generated, override getUniqueVariableName.
		 * If you need special behavior regarding the result variable itself, override createResultVariable. 
		 *
		 * The variable is not initialized at first but only after it has been declared. 
		 * This is the only way to allow for easy unraveling while correctly compiling f() && g()
		 */
		val resultVariable = createResultVariable(obj);
		
		val unraveledInitialization = createInitialization(obj);
		/* We create two references to the variable:
		 * - One for usage in chained conditional evaluations, such as f() && g()
		 * - One for the original location
		 */
		val resultVariableReference1 = createResultVariableReference(resultVariable);
		val resultVariableReference2 = createResultVariableReference(resultVariable);
		// This will initialize the variable
		val initialization = createAssignmentStatement(resultVariableReference1, unraveledInitialization)
		
		// conditional chained evaluation, such as f() && g(), is present only if we are in a BinaryExpression or a ConditionalExpression
		val logicalBinaryExpression = EcoreUtil2.getContainerOfType(obj, BinaryExpression);
		val conditionalExpression = EcoreUtil2.getContainerOfType(obj, ConditionalExpression);
		// if both are not null, one must be contained in the other. We use the inner one here.
		val conditionSource = if(logicalBinaryExpression !== null && conditionalExpression !== null) {
			if(logicalBinaryExpression.eAllContents.findFirst[it === conditionalExpression] !== null) {
				conditionalExpression;
			}
			else {
				logicalBinaryExpression;
			}
		}
		else {
			logicalBinaryExpression ?: conditionalExpression;
		}
		
		val initializationStmt = if(conditionSource !== null) {
			val condition = getCondition(obj, conditionSource);
			if(condition === null) {
				initialization;
			}
			else {
				val ifStmt = ProgramFactory.eINSTANCE.createIfStatement();
				ifStmt.condition = condition;
				ifStmt.then = ProgramFactory.eINSTANCE.createProgramBlock() => [ block |
					block.content += initialization;
				]
				ifStmt;	
			}
		} else {
			initialization;
		}
		
		/* We have to find the insertion point for the resultVariable before we replace the unraveling object with the
		 * reference to the result variable and thus make it impossible to find the original context.
		 */
		val originalContext = findOriginalContext(obj);
		obj.replaceWith(resultVariableReference2);

		/* Inserting the result variable itself is a post transformation as it modifies the children
		 * of its container and thus would lead to a ConcurrentModificationException.
		 * 
		 * Note how by calling transformChildren (in doTransform) before doUnravel we transform depth first and
		 * thus maintain the correct order of result variables (as all inserting post transformations are in the
		 * correct order). This way initialization code which references other unraveled code (e.g. f(g(h(x))))
		 * will reference existing result variables.
		 */
		addPostTransformation([ insertNextToParentBlock(originalContext, true, resultVariable) ]);
		addPostTransformation([ insertNextToParentBlock(resultVariable, false, initializationStmt) ]);
	}

	protected def Expression createResultVariableReference(AbstractStatement resultVariable) {
		val resultVariableReference = ExpressionsFactory.eINSTANCE.createElementReferenceExpression;
		resultVariableReference.reference = resultVariable;
		return resultVariableReference;
	}
	
	protected def AbstractStatement createAssignmentStatement(Expression varRef, Expression initialization) {
		val initializationExpr = ExpressionsFactory.eINSTANCE.createAssignmentExpression();
		initializationExpr.varRef = varRef;
		initializationExpr.expression = initialization;		
		val initializationStmt = ExpressionsFactory.eINSTANCE.createExpressionStatement();
		initializationStmt.expression = initializationExpr;
		return initializationStmt;
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
		ProgramCopier.linkOrigin(copy, ProgramCopier.getOrigin(expression));
		return copy;
	}

	protected def AbstractStatement createResultVariable(Expression unravelingObject) {
		val resultVariableName = getUniqueVariableName(unravelingObject).toFirstLower;
		val resultVariable = ProgramFactory.eINSTANCE.createVariableDeclaration;
		resultVariable.name = resultVariableName;
		return resultVariable;
	}

	protected def getUniqueVariableName(Expression unravelingObject) {
		return generatorUtils.getUniqueIdentifier(unravelingObject);
	}

	protected def findOriginalContext(EObject unravelingObject) {
		var originalContext = unravelingObject.eContainer;
		while (originalContext.eContainer !== null && !(originalContext.eContainer instanceof ProgramBlock) &&
			!(originalContext.eContainer instanceof Program)) {
			originalContext = originalContext.eContainer;
		}
		return originalContext;
	}

}
