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

import com.google.inject.Inject
import java.util.Optional
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.types.CoercionExpression
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable

/**
 * Interface for type generators.
 */
abstract class AbstractTypeGenerator implements IGenerator { 
	@Inject
	protected TypeGenerator typeGenerator
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject
	protected extension GeneratorUtils
	
	/**
	 * Produces a code fragment with the actual type specifier
	 */
	def CodeFragment generateTypeSpecifier(AbstractType type, EObject context) {
		codeFragmentProvider.create('''«typeGenerator.code(context, type)»''')
	}
	
	/**
	 * Produces a variable declaration for a variable of a generated type
	 */
	def CodeFragment generateVariableDeclaration(AbstractType type, EObject context, CodeFragment varName, Expression initialization, boolean isTopLevel) {
		codeFragmentProvider.create('''«typeGenerator.code(context, type)» «varName»;''')
	}
	
	/**
	 * Produces initialization code that cannot be put globally.
	 */
	def CodeFragment generateGlobalInitialization(AbstractType type, EObject context, CodeFragment varName, Expression initialization) {
		CodeFragment.EMPTY;
	}
		
	/**
	 * Produces code which implements an assignment operation. 
	 * Every generator should be able to at least handle AssignmentOperator.ASSIGN. 
	 * left can be used for size inference, but might not exist, for example when copying inner structures.
	 * leftName might be a C expression (for example `(*_result)`), to generate temporary variable names use cVariablePrefix. 
	 */
	def CodeFragment generateExpression(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, AssignmentOperator operator, CodeWithContext right) {
		return codeFragmentProvider.create('''«left.code»«IF right !== null» «operator.literal» «right.code»«ENDIF»;''');
	}
	
	/**
	 * Produces code that reserves static memory (global/stack) for *count* instances.
	 * Left is a C-array of length at least *count*.
	 * Produced C-code might be global.
	 */
	def CodeFragment generateBulkAllocation(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, CodeFragment count, boolean isTopLevel);
	
	/**
	 * Produces code that assigns *count* instances in left.
	 * Left is a C-array of length at least *count*.
	 * Produced C-code is always in a function context.
	 */
	def CodeFragment generateBulkAssignment(EObject context, CodeFragment cVariablePrefix, CodeWithContext left, CodeFragment count);
	
	/**
	 * Produces code that bulk copies data from C-array to C-array.
	 */
	def CodeFragment generateBulkCopyStatements(EObject context, CodeFragment i, CodeWithContext left, CodeWithContext right, CodeFragment count);
	
	/**
	 * Produces header definitions. Called only once.
	 */
	def CodeFragment generateHeader() {
		return CodeFragment.EMPTY;
	}
	
	/**
	 * Produces function definitions. Called only once.
	 */
	def CodeFragment generateImplementation() {
		return CodeFragment.EMPTY;
	}
	
	def CodeFragment generateCoercion(CoercionExpression expr, AbstractType from, AbstractType to) {
		return codeFragmentProvider.create('''
		ERROR: CANT COERCE FROM «from» to «to» (expr.eClass = «expr.eClass.name»). THIS IS MOST LIKELY A BUG IN THE COMPILER, PLEASE REPORT
		''')
	}
	
	/**
	 * Produces header definitions, called per different instance of type arguments.
	 * For now implementors need to check that all data types contained in type are bound to an actual type (instanceof TypeVariable is false). 
	 */
	def CodeFragment generateHeader(EObject context, AbstractType type) {
		return CodeFragment.EMPTY;
	}
	/**
	 * Produces header type implementations, called per different instance of type arguments.
	 */
	def CodeFragment generateTypeImplementations(EObject context, AbstractType type) {
		return CodeFragment.EMPTY;
	}
	
	protected def getRelevantTypeParametersForHeaderName(Iterable<AbstractType> allTypeArguments) {
		return allTypeArguments.tail;
	}
	
	def String generateHeaderName(EObject context, TypeConstructorType t) {
		val relevantTypeParameters = getRelevantTypeParametersForHeaderName(t.typeArguments)
		if(!relevantTypeParameters.filter(TypeVariable).empty) {
			return null
		}
		return '''«(#[t.name] + relevantTypeParameters.map[getFileNameForTypeImplementation(context, it)]).filterNull.join("_")»'''
	}
	
	def String generateUnspecializedDefinitionsHeaderName(EObject context, TypeConstructorType typeWitness) {
		return typeWitness.name
	}
}