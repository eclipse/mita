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

package org.eclipse.mita.program.generator

import com.google.common.base.Optional
import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.types.CoercionExpression
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.typesystem.infra.SubtypeChecker
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.inferrer.ValidElementSizeInferenceResult

/**
 * Interface for type generators.
 */
abstract class AbstractTypeGenerator implements IGenerator {

	@Inject SubtypeChecker subtypeChecker;
 
	@Inject
	protected TypeGenerator typeGenerator
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	/**
	 * Produces a code fragment with the actual type specifier
	 */
	def CodeFragment generateTypeSpecifier(AbstractType type, EObject context) {
		codeFragmentProvider.create('''«typeGenerator.code(context, type)»''')
	}
	
	/**
	 * Produces a variable declaration for a variable of a generated type
	 */
	def CodeFragment generateVariableDeclaration(AbstractType type, EObject context, ValidElementSizeInferenceResult size, CodeFragment varName, Expression initialization, boolean isTopLevel) {
		codeFragmentProvider.create('''«typeGenerator.code(context, type)» «varName»;''')
	}
	
	/**
	 * Produces a new instance of the type
	 */
	def CodeFragment generateNewInstance(AbstractType type, NewInstanceExpression expr);
	
	/**
	 * Produces code which implements an assignment operation. 
	 * Every generator should be able to at least handle AssignmentOperator.ASSIGN. 
	 * left can be used for size inference, but might not exist, for example when copying inner structures.
	 * leftName might be a C expression (for example `(*_result)`), to generate temporary variable names use cVariablePrefix. 
	 */
	def CodeFragment generateExpression(AbstractType type, EObject context, Optional<EObject> left, CodeFragment leftName, CodeFragment cVariablePrefix, AssignmentOperator operator, EObject right) {
		return codeFragmentProvider.create('''«leftName» «operator.literal» «right»;''');
	}
	
	/**
	 * Produces header definitions. Called only once.
	 */
	def CodeFragment generateHeader() {
		return CodeFragment.EMPTY;
	}
	
	def CodeFragment generateCoercion(CoercionExpression expr, AbstractType from, AbstractType to) {
		return codeFragmentProvider.create('''
		ERROR: CANT COERCE FROM «from» to «to» (expr.eClass = «expr.eClass.name»). THIS IS MOST LIKELY A BUG IN THE COMPILER, PLEASE REPORT
		''')
	}
	
	/**
	 * Produces header definitions, called per different instance of type arguments.
	 */
	def CodeFragment generateHeader(EObject context, AbstractType type) {
		return CodeFragment.EMPTY;
	}
}